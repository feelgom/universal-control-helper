import AppKit
import Sparkle
import UniversalControlCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var statusItem: NSStatusItem!
    private var transport: RelayTransport?
    private var sourceClient: SourceClient?
    private var inputRelay: InputRelay?
    private var settingsController: SettingsWindowController?
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
        statusItem.button?.title = "⌨︎↔︎"
        configureMainMenu()
        _ = updaterController
        configureForCurrentRole()
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    private func configureForCurrentRole() {
        transport?.stop()
        transport = nil
        sourceClient = nil
        inputRelay?.stop()
        inputRelay = nil
        inputMonitoringReady = preferences.role == .target

        switch preferences.role {
        case .source:
            let client = SourceClient { [weak self] in self?.preferences.pairingCode ?? "" }
            let relay = InputRelay { [weak self] in self?.preferences.pairingCode ?? "" }
            relay.send = { [weak client] message in client?.send(message) }
            client.statusDidChange = { [weak self] status in
                self?.connectionStatus = status
                self?.refreshInterface()
            }
            sourceClient = client
            inputRelay = relay
            transport = client
            client.start()
            inputMonitoringReady = relay.start()

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
            inputMonitoringReady: inputMonitoringReady
        )
    }

    private func refreshInterface() {
        rebuildMenu()
        settingsController?.update(snapshot: settingsSnapshot)
        settingsController?.refreshPermissionStatus()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Universal Control Helper")

        let settings = NSMenuItem(title: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
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

        let title = NSMenuItem(title: "Universal Control Helper", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let source = NSMenuItem(title: "키보드 Mac (Source)", action: #selector(selectSource), keyEquivalent: "")
        source.target = self
        source.state = preferences.role == .source ? .on : .off
        menu.addItem(source)

        let target = NSMenuItem(title: "대상 Mac (Target)", action: #selector(selectTarget), keyEquivalent: "")
        target.target = self
        target.state = preferences.role == .target ? .on : .off
        menu.addItem(target)
        menu.addItem(.separator())

        let status = NSMenuItem(title: displayedConnectionStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let pairing = NSMenuItem(
            title: "페어링 코드: \(preferences.pairingCode)…",
            action: #selector(showPairingSettings),
            keyEquivalent: ""
        )
        pairing.target = self
        menu.addItem(pairing)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let updates = NSMenuItem(title: "업데이트 확인…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        updates.isEnabled = updaterController.updater.canCheckForUpdates
        menu.addItem(updates)

        let about = NSMenuItem(title: "사용 방법", action: #selector(showInstructions), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
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

    @objc private func selectSource() {
        setRole(.source)
    }

    @objc private func selectTarget() {
        setRole(.target)
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
        guard preferences.role == .source, let inputRelay else {
            inputMonitoringReady = preferences.role == .target
            refreshInterface()
            return inputMonitoringReady
        }

        inputRelay.stop()
        inputMonitoringReady = inputRelay.start()
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
        return controller
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = makeSettingsController()
        }
        settingsController?.present(snapshot: settingsSnapshot)
    }

    @objc private func showPairingSettings() {
        if settingsController == nil {
            settingsController = makeSettingsController()
        }
        settingsController?.present(snapshot: settingsSnapshot, focusPairingCode: true)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func showInstructions() {
        showInfo(
            title: "Universal Control Helper 사용 방법",
            message: "1. ⌘, 또는 메뉴의 설정을 엽니다.\n2. 키보드가 연결된 Mac은 Source, 다른 Mac은 Target으로 설정합니다.\n3. Source에 자동 생성된 6자리 코드를 Target에 입력합니다.\n4. Source에서 입력 모니터링을 허용합니다.\n\n이후 Source에서 Caps Lock을 누르면 로컬 한/영 전환은 유지되고 Target의 한국어/ABC 입력 소스도 함께 전환됩니다."
        )
    }

    private func showInfo(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if statusItem != nil {
            _ = refreshInputMonitoring()
            if settingsController?.window?.isVisible != true {
                showSettings()
            }
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
        inputRelay?.stop()
        transport?.stop()
    }
}
