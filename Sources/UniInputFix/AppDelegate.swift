import AppKit
import Sparkle
import UniInputCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var statusItem: NSStatusItem!
    private var transport: RelayTransport?
    private var sourceClient: SourceClient?
    private var inputRelay: InputRelay?
    private var connectionStatus = "시작 중"
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨︎↔︎"
        _ = updaterController
        configureForCurrentRole()
        rebuildMenu()

        if preferences.role == .source, !requestAccessibilityPermission() {
            showInfo(
                title: "접근성 권한이 필요합니다",
                message: "Caps Lock을 읽고 로컬 동작을 막으려면 시스템 설정 > 개인정보 보호 및 보안에서 UniInputFix의 접근성과 입력 모니터링 권한을 허용해 주세요."
            )
        }
    }

    private func configureForCurrentRole() {
        transport?.stop()
        transport = nil
        sourceClient = nil
        inputRelay?.stop()
        inputRelay = nil

        switch preferences.role {
        case .source:
            let client = SourceClient { [weak self] in self?.preferences.pairingCode ?? "" }
            let relay = InputRelay { [weak self] in self?.preferences.pairingCode ?? "" }
            relay.isRelayActive = preferences.relayActive
            relay.send = { [weak client] message in client?.send(message) }
            relay.relayActiveDidChange = { [weak self] active in
                self?.preferences.relayActive = active
                self?.rebuildMenu()
            }
            client.statusDidChange = { [weak self] status in
                self?.connectionStatus = status
                self?.rebuildMenu()
            }
            sourceClient = client
            inputRelay = relay
            transport = client
            client.start()
            if !relay.start() {
                connectionStatus = "접근성 권한 필요"
            }
        case .target:
            preferences.relayActive = false
            let server = TargetServer { [weak self] in self?.preferences.pairingCode ?? "" }
            server.messageReceived = { message in TargetInputInjector.handle(message) }
            server.statusDidChange = { [weak self] status in
                self?.connectionStatus = status
                self?.rebuildMenu()
            }
            transport = server
            server.start()
        }
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()

        let title = NSMenuItem(title: "UniInput Fix", action: nil, keyEquivalent: "")
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

        let status = NSMenuItem(title: connectionStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if preferences.role == .source {
            let relayTitle = preferences.relayActive ? "Caps Lock 보정 끄기" : "Caps Lock 보정 켜기"
            let relay = NSMenuItem(title: relayTitle, action: #selector(toggleRelay), keyEquivalent: "u")
            relay.keyEquivalentModifierMask = [.command, .option, .control]
            relay.target = self
            relay.state = preferences.relayActive ? .on : .off
            menu.addItem(relay)
        }

        let pairing = NSMenuItem(title: "페어링 코드: \(preferences.pairingCode)…", action: #selector(changePairingCode), keyEquivalent: "")
        pairing.target = self
        menu.addItem(pairing)
        menu.addItem(.separator())

        let updates = NSMenuItem(title: "업데이트 확인…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        updates.isEnabled = updaterController.updater.canCheckForUpdates
        menu.addItem(updates)

        let accessibility = NSMenuItem(title: "접근성 설정 열기", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)

        let inputSettings = NSMenuItem(title: "입력 소스 설정 열기", action: #selector(openInputSettings), keyEquivalent: "")
        inputSettings.target = self
        menu.addItem(inputSettings)

        let about = NSMenuItem(title: "사용 방법", action: #selector(showInstructions), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "UniInput Fix 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func selectSource() {
        guard preferences.role != .source else { return }
        preferences.role = .source
        connectionStatus = "시작 중"
        configureForCurrentRole()
        rebuildMenu()
    }

    @objc private func selectTarget() {
        guard preferences.role != .target else { return }
        preferences.role = .target
        connectionStatus = "시작 중"
        configureForCurrentRole()
        rebuildMenu()
    }

    @objc private func toggleRelay() {
        inputRelay?.isRelayActive.toggle()
        rebuildMenu()
    }

    @objc private func changePairingCode() {
        let alert = NSAlert()
        alert.messageText = "페어링 코드"
        alert.informativeText = "두 Mac에 같은 6자리 숫자를 입력하세요."
        alert.addButton(withTitle: "적용")
        alert.addButton(withTitle: "취소")
        let field = NSTextField(string: preferences.pairingCode)
        field.placeholderString = "6자리 숫자"
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PairingCode.isValid(value) else {
            showInfo(title: "올바르지 않은 코드", message: "숫자 6자리로 입력해 주세요.")
            return
        }
        preferences.pairingCode = value
        connectionStatus = "새 코드로 다시 연결 중"
        configureForCurrentRole()
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func openInputSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    @objc private func showInstructions() {
        showInfo(
            title: "UniInput Fix 사용 방법",
            message: "1. 키보드가 연결된 Mac은 Source로 둡니다.\n2. 다른 Mac에도 앱을 복사해 Target으로 바꿉니다.\n3. 두 Mac의 6자리 페어링 코드를 같게 맞춥니다.\n4. Universal Control로 대상 Mac을 사용할 때 Source에서 Caps Lock 보정을 켭니다.\n\n⌃⌥⌘U로 보정을 빠르게 켜고 끌 수 있습니다. 보정이 켜진 동안 Caps Lock은 대상 Mac의 한국어/ABC 입력 소스 전환으로 처리됩니다."
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputRelay?.stop()
        transport?.stop()
    }
}
