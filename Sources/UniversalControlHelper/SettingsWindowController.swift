import AppKit
import SwiftUI

struct SettingsSnapshot {
    let role: ComputerRole
    let pairingCode: String
    let connectionStatus: String
    let helperEnabled: Bool
    let currentVersion: String
    let canCheckForUpdates: Bool
    let launchAtLoginState: LaunchAtLoginState
}

final class SettingsViewModel: ObservableObject {
    @Published private(set) var role: ComputerRole = .source
    @Published var pairingCode = ""
    @Published private(set) var connectionStatus = "시작 중"
    @Published private(set) var helperEnabled = true
    @Published private(set) var currentVersion = "-"
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginRequiresApproval = false
    @Published private(set) var launchAtLoginFeedback: String?
    @Published var pairingCodeFeedback: String?
    @Published var pairingCodeIsValid = true
    private var pairingCodeIsDirty = false

    var roleDidChange: ((ComputerRole) -> Void)?
    var pairingCodeDidChange: ((String) -> Bool)?
    var pairingCodeRegenerationRequested: (() -> String)?
    var helperEnabledDidChange: ((Bool) -> Void)?
    var updateCheckRequested: (() -> Void)?
    var launchAtLoginDidChange: ((Bool) -> LaunchAtLoginChangeResult)?

    func update(snapshot: SettingsSnapshot) {
        role = snapshot.role
        if !pairingCodeIsDirty {
            pairingCode = snapshot.pairingCode
        }
        connectionStatus = snapshot.connectionStatus
        helperEnabled = snapshot.helperEnabled
        currentVersion = snapshot.currentVersion
        canCheckForUpdates = snapshot.canCheckForUpdates
        applyLaunchAtLoginState(snapshot.launchAtLoginState)
    }

    func selectRole(_ newRole: ComputerRole) {
        role = newRole
        pairingCodeIsDirty = false
        pairingCodeFeedback = nil
        roleDidChange?(newRole)
    }

    func applyPairingCode() {
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if pairingCodeDidChange?(code) == true {
            pairingCode = code
            pairingCodeIsDirty = false
            pairingCodeIsValid = true
            pairingCodeFeedback = "적용되었습니다. 새 코드로 연결을 다시 시작합니다."
        } else {
            pairingCodeIsValid = false
            pairingCodeFeedback = "숫자 6자리를 정확히 입력해 주세요."
        }
    }

    func editPairingCode(_ code: String) {
        pairingCode = code
        pairingCodeIsDirty = true
        pairingCodeFeedback = nil
        pairingCodeIsValid = true
    }

    func regeneratePairingCode() {
        guard let code = pairingCodeRegenerationRequested?(), !code.isEmpty else { return }
        pairingCode = code
        pairingCodeIsDirty = false
        pairingCodeIsValid = true
        pairingCodeFeedback = "새 코드를 생성했습니다. Target Mac에 입력해 주세요."
    }

    func checkForUpdates() {
        updateCheckRequested?()
    }

    func setHelperEnabled(_ enabled: Bool) {
        helperEnabled = enabled
        helperEnabledDidChange?(enabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard let result = launchAtLoginDidChange?(enabled) else { return }
        applyLaunchAtLoginState(result.state)
        launchAtLoginFeedback = result.message
    }

    func openLoginItemsSettings() {
        LaunchAtLogin.openSystemSettings()
    }

    private func applyLaunchAtLoginState(_ state: LaunchAtLoginState) {
        launchAtLoginEnabled = state.isEnabled
        launchAtLoginRequiresApproval = state == .requiresApproval
        if state != .requiresApproval {
            launchAtLoginFeedback = nil
        }
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var roleDidChange: ((ComputerRole) -> Void)?
    var pairingCodeDidChange: ((String) -> Bool)?
    var pairingCodeRegenerationRequested: (() -> String)?
    var helperEnabledDidChange: ((Bool) -> Void)?
    var updateCheckRequested: (() -> Void)?
    var launchAtLoginDidChange: ((Bool) -> LaunchAtLoginChangeResult)?
    var windowDidClose: (() -> Void)?

    private let model = SettingsViewModel()

    init() {
        let rootView = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Universal Control Helper 설정"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 590))
        window.minSize = NSSize(width: 560, height: 550)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        model.roleDidChange = { [weak self] role in self?.roleDidChange?(role) }
        model.pairingCodeDidChange = { [weak self] code in
            self?.pairingCodeDidChange?(code) ?? false
        }
        model.pairingCodeRegenerationRequested = { [weak self] in
            self?.pairingCodeRegenerationRequested?() ?? ""
        }
        model.helperEnabledDidChange = { [weak self] enabled in
            self?.helperEnabledDidChange?(enabled)
        }
        model.updateCheckRequested = { [weak self] in
            self?.updateCheckRequested?()
        }
        model.launchAtLoginDidChange = { [weak self] enabled in
            self?.launchAtLoginDidChange?(enabled)
                ?? LaunchAtLoginChangeResult(state: .unavailable, message: nil)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(snapshot: SettingsSnapshot) {
        model.update(snapshot: snapshot)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func update(snapshot: SettingsSnapshot) {
        model.update(snapshot: snapshot)
    }

    func windowWillClose(_ notification: Notification) {
        windowDidClose?()
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            generalSection
            connectionSection
            softwareUpdateSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 550, idealHeight: 590)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .accessibilityLabel("Universal Control Helper 앱 아이콘")

            VStack(alignment: .leading, spacing: 3) {
                Text("Universal Control Helper")
                    .font(.title2.weight(.semibold))
                Text("두 Mac의 한/영 입력 소스를 자동으로 맞춥니다.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionSection: some View {
        GroupBox("연결") {
            VStack(alignment: .leading, spacing: 14) {
                Picker(
                    "이 Mac의 역할",
                    selection: Binding(
                        get: { model.role },
                        set: { model.selectRole($0) }
                    )
                ) {
                    Text("키보드 Mac (Source)").tag(ComputerRole.source)
                    Text("대상 Mac (Target)").tag(ComputerRole.target)
                }
                .pickerStyle(.segmented)

                Divider()

                LabeledContent("연결 상태") {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 9, height: 9)
                        Text(model.connectionStatus)
                            .lineLimit(1)
                    }
                }

                pairingCodeRow

                if let feedback = model.pairingCodeFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(model.pairingCodeIsValid ? Color.green : Color.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text(
                        model.role == .source
                            ? "이 코드를 Target Mac에 입력하세요."
                            : "Source Mac에 표시된 숫자 6자리를 입력하세요."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Text(roleExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var pairingCodeRow: some View {
        if model.role == .source {
            LabeledContent("페어링 코드") {
                HStack(spacing: 10) {
                    Text(model.pairingCode)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                    Button("재생성") { model.regeneratePairingCode() }
                        .accessibilityLabel("페어링 코드 재생성")
                }
            }
        } else {
            LabeledContent("페어링 코드") {
                HStack(spacing: 8) {
                    TextField(
                        "숫자 6자리",
                        text: Binding(
                            get: { model.pairingCode },
                            set: { model.editPairingCode($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .frame(width: 130)
                    .onSubmit { model.applyPairingCode() }
                    .accessibilityLabel("페어링 코드")
                    Button("적용") { model.applyPairingCode() }
                        .accessibilityLabel("페어링 코드 적용")
                }
            }
        }
    }

    private var generalSection: some View {
        GroupBox("일반") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(
                    "Universal Control Helper 사용",
                    isOn: Binding(
                        get: { model.helperEnabled },
                        set: { model.setHelperEnabled($0) }
                    )
                )
                .accessibilityLabel("Universal Control Helper 사용")

                Divider()

                Toggle(
                    "Mac에 로그인할 때 자동으로 실행",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .accessibilityLabel("Mac에 로그인할 때 자동으로 실행")

                if let feedback = model.launchAtLoginFeedback {
                    HStack(alignment: .firstTextBaseline) {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if model.launchAtLoginRequiresApproval {
                            Button("로그인 항목 설정 열기") {
                                model.openLoginItemsSettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }

            }
            .padding(8)
        }
    }

    private var softwareUpdateSection: some View {
        GroupBox("소프트웨어 업데이트") {
            LabeledContent("현재 버전") {
                HStack(spacing: 10) {
                    Text(model.currentVersion)
                        .foregroundStyle(.secondary)
                    Button("업데이트 확인…") {
                        model.checkForUpdates()
                    }
                    .disabled(!model.canCheckForUpdates)
                    .accessibilityLabel("새 버전 확인")
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionColor: Color {
        if model.connectionStatus.contains("연결됨") || model.connectionStatus.contains("준비 완료") {
            return .green
        }
        if model.connectionStatus.contains("오류")
            || model.connectionStatus.contains("필요")
            || model.connectionStatus.contains("불일치") {
            return .red
        }
        return .orange
    }

    private var roleExplanation: String {
        switch model.role {
        case .source:
            return "Source의 ABC/두벌식 변경을 Target에 자동으로 동기화합니다."
        case .target:
            return "Source에서 선택한 ABC/두벌식 상태를 그대로 적용합니다."
        }
    }
}
