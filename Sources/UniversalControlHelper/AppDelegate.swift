import AppKit
import Sparkle
import UniversalControlCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var statusItem: NSStatusItem!
    private var transport: RelayTransport?
    private var sourceClient: SourceClient?
    private var inputSourceRelay: InputSourceRelay?
    private var physicalCapsLockMonitor: PhysicalCapsLockMonitor?
    private var settingsController: SettingsWindowController?
    private var updaterReadinessObservation: NSKeyValueObservation?
    private var connectionStatus = "시작 중"
    private var inputMonitoringReady = false
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemButton()
        configureMainMenu()
        _ = updaterController
        updaterReadinessObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in self?.refreshInterface() }
        }
        configureForCurrentRole()
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    private func configureStatusItemButton() {
        guard let button = statusItem.button else { return }
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            button.title = "⌨︎↔︎"
            return
        }

        image.isTemplate = true
        image.size = NSSize(width: 24, height: 9)
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Universal Control Helper"
    }

    private func configureForCurrentRole() {
        transport?.stop()
        transport = nil
        sourceClient = nil
        inputSourceRelay?.stop()
        inputSourceRelay = nil
        physicalCapsLockMonitor?.stop()
        physicalCapsLockMonitor = nil
        inputMonitoringReady = preferences.role == .target

        guard preferences.helperEnabled else {
            connectionStatus = "꺼짐"
            inputMonitoringReady = false
            refreshInterface()
            return
        }

        switch preferences.role {
        case .source:
            let client = SourceClient { [weak self] in self?.preferences.pairingCode ?? "" }
            let relay = InputSourceRelay()
            let physicalMonitor = PhysicalCapsLockMonitor()
            relay.send = { [weak client] state in client?.synchronizeInputSource(state) }
            physicalMonitor.onCapsLockPressed = { [weak client] in client?.toggleInputSource() }
            client.authenticationDidComplete = { [weak relay] peerProtocolVersion in
                if peerProtocolVersion >= RelayProtocol.currentVersion {
                    relay?.synchronizeCurrentState()
                }
            }
            client.statusDidChange = { [weak self] status in
                self?.connectionStatus = status
                self?.refreshInterface()
            }
            sourceClient = client
            inputSourceRelay = relay
            physicalCapsLockMonitor = physicalMonitor
            transport = client
            client.start()
            relay.start()
            inputMonitoringReady = physicalMonitor.start()

        case .target:
            let server = TargetServer { [weak self] in self?.preferences.pairingCode ?? "" }
            server.messageReceived = { message in TargetInputInjector.handle(message) }
            server.statusDidChange = { [weak self] status in
                self?.connectionStatus = status
                self?.refreshInterface()
            }
            transport = server
            server.start()
        }

        refreshInterface()
    }

    private var displayedConnectionStatus: String {
        if !preferences.helperEnabled {
            return "꺼짐"
        }
        if preferences.role == .source, !inputMonitoringReady {
            return "입력 모니터링 권한 필요"
        }
        return connectionStatus
    }

    private var settingsSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            role: preferences.role,
            pairingCode: preferences.pairingCode,
            connectionStatus: displayedConnectionStatus,
            inputMonitoringReady: inputMonitoringReady,
            helperEnabled: preferences.helperEnabled,
            currentVersion: displayedVersion,
            canCheckForUpdates: updaterController.updater.canCheckForUpdates,
            launchAtLoginState: LaunchAtLogin.state
        )
    }

    private var displayedVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "개발 빌드"
        let build = info?["CFBundleVersion"] as? String
        guard let build, build != version else { return version }
        return "\(version) (\(build))"
    }

    private func refreshInterface() {
        rebuildMenu()
        settingsController?.update(snapshot: settingsSnapshot)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Universal Control Helper")

        let settings = NSMenuItem(title: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)

        let closeWindow = NSMenuItem(
            title: "윈도우 닫기",
            action: #selector(closeSettingsWindow),
            keyEquivalent: "w"
        )
        closeWindow.target = self
        appMenu.addItem(closeWindow)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Universal Control Helper 종료",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()

        let header = NSMenuItem()
        let headerView = StatusMenuHeaderView(isEnabled: preferences.helperEnabled)
        headerView.enabledDidChange = { [weak self] enabled in
            self?.setHelperEnabled(enabled)
        }
        header.view = headerView
        menu.addItem(header)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Universal Control Helper 종료",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func setRole(_ role: ComputerRole) {
        guard preferences.role != role else {
            refreshInterface()
            return
        }
        preferences.role = role
        connectionStatus = "시작 중"
        configureForCurrentRole()
    }

    private func setHelperEnabled(_ enabled: Bool) {
        guard preferences.helperEnabled != enabled else {
            refreshInterface()
            return
        }
        preferences.helperEnabled = enabled
        connectionStatus = enabled ? "시작 중" : "꺼짐"
        configureForCurrentRole()
    }

    private func applyPairingCode(_ code: String) -> Bool {
        guard PairingCode.isValid(code) else { return false }
        guard preferences.pairingCode != code else { return true }
        preferences.pairingCode = code
        connectionStatus = "새 코드로 다시 연결 중"
        configureForCurrentRole()
        return true
    }

    private func regeneratePairingCode() -> String {
        let code = PairingCode.generate()
        preferences.pairingCode = code
        connectionStatus = "새 코드로 다시 연결 중"
        configureForCurrentRole()
        return code
    }

    private func refreshInputMonitoring() -> Bool {
        guard preferences.role == .source, let physicalCapsLockMonitor else {
            inputMonitoringReady = preferences.role == .target
            refreshInterface()
            return inputMonitoringReady
        }

        physicalCapsLockMonitor.stop()
        inputMonitoringReady = physicalCapsLockMonitor.start()
        refreshInterface()
        return inputMonitoringReady
    }

    private func makeSettingsController() -> SettingsWindowController {
        let controller = SettingsWindowController()
        controller.roleDidChange = { [weak self] role in self?.setRole(role) }
        controller.pairingCodeDidChange = { [weak self] code in
            self?.applyPairingCode(code) ?? false
        }
        controller.pairingCodeRegenerationRequested = { [weak self] in
            self?.regeneratePairingCode() ?? ""
        }
        controller.permissionRefreshRequested = { [weak self] in
            self?.refreshInputMonitoring() ?? false
        }
        controller.permissionResetRequested = { [weak self] in
            self?.resetInputMonitoring()
        }
        controller.helperEnabledDidChange = { [weak self] enabled in
            self?.setHelperEnabled(enabled)
        }
        controller.updateCheckRequested = { [weak self] in self?.checkForUpdates() }
        controller.launchAtLoginDidChange = { [weak self] enabled in
            let result = LaunchAtLogin.setEnabled(enabled)
            self?.refreshInterface()
            return result
        }
        controller.windowDidClose = {
            NSApp.setActivationPolicy(.accessory)
        }
        return controller
    }

    private func resetInputMonitoring() {
        let alert = NSAlert()
        alert.messageText = "입력 모니터링 권한을 다시 등록할까요?"
        alert.informativeText = "Universal Control Helper의 오래된 권한 항목만 제거합니다. 다른 앱의 권한은 변경하지 않습니다."
        alert.addButton(withTitle: "재등록")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        physicalCapsLockMonitor?.stop()
        inputMonitoringReady = false
        guard AppPermissions.resetInputMonitoring() else {
            let failure = NSAlert()
            failure.messageText = "권한 항목을 초기화하지 못했습니다."
            failure.informativeText = "터미널에서 다음 명령을 실행해 주세요.\n\ntccutil reset ListenEvent io.yoonsungji.UniInputFix"
            failure.addButton(withTitle: "확인")
            failure.runModal()
            return
        }

        connectionStatus = "입력 모니터링을 다시 허용해 주세요"
        _ = refreshInputMonitoring()
        AppPermissions.openInputMonitoringSettings()
    }

    @objc private func showSettings() {
        NSApp.setActivationPolicy(.regular)
        if settingsController == nil {
            settingsController = makeSettingsController()
        }
        settingsController?.present(snapshot: settingsSnapshot)
    }

    @objc private func closeSettingsWindow() {
        settingsController?.window?.performClose(nil)
    }

    private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if statusItem != nil, preferences.role == .source, !inputMonitoringReady {
            _ = refreshInputMonitoring()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        physicalCapsLockMonitor?.stop()
        inputSourceRelay?.stop()
        transport?.stop()
    }
}

private final class StatusMenuHeaderView: NSView {
    var enabledDidChange: ((Bool) -> Void)?

    private let enabledSwitch = PersistentTintSwitch()

    init(isEnabled: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 310, height: 64))

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Universal Control Helper")
        title.font = .systemFont(ofSize: 14, weight: .semibold)

        title.translatesAutoresizingMaskIntoConstraints = false

        enabledSwitch.isOn = isEnabled
        enabledSwitch.target = self
        enabledSwitch.action = #selector(switchChanged)
        enabledSwitch.setAccessibilityLabel("Universal Control Helper 사용")
        enabledSwitch.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(title)
        addSubview(enabledSwitch)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 38),
            iconView.heightAnchor.constraint(equalToConstant: 38),
            title.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: enabledSwitch.leadingAnchor, constant: -10),
            enabledSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            enabledSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func switchChanged() {
        enabledDidChange?(enabledSwitch.isOn)
    }
}

private final class PersistentTintSwitch: NSControl {
    var isOn = false {
        didSet {
            setAccessibilityValue(isOn)
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 46, height: 26)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.checkBox)
        setAccessibilityValue(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 1, dy: 1)
        let track = NSBezierPath(
            roundedRect: trackRect,
            xRadius: trackRect.height / 2,
            yRadius: trackRect.height / 2
        )
        let trackColor: NSColor
        if isOn {
            trackColor = .controlAccentColor
        } else {
            trackColor = .tertiaryLabelColor.withAlphaComponent(0.45)
        }
        trackColor.setFill()
        track.fill()

        let thumbDiameter = trackRect.height - 4
        let thumbX = isOn
            ? trackRect.maxX - thumbDiameter - 2
            : trackRect.minX + 2
        let thumbRect = NSRect(
            x: thumbX,
            y: trackRect.minY + 2,
            width: thumbDiameter,
            height: thumbDiameter
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: thumbRect).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        toggleAndSendAction()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        toggleAndSendAction()
        return true
    }

    private func toggleAndSendAction() {
        isOn.toggle()
        sendAction(action, to: target)
    }
}
