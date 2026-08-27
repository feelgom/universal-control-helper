import AppKit
import SwiftUI

struct SettingsSnapshot {
    let role: ComputerRole
    let pairingCode: String
    let connectionStatus: String
    let inputMonitoringReady: Bool
    let helperEnabled: Bool
    let currentVersion: String
    let canCheckForUpdates: Bool
    let launchAtLoginState: LaunchAtLoginState
}

final class SettingsViewModel: ObservableObject {
    @Published private(set) var role: ComputerRole = .source
    @Published var pairingCode = ""
    @Published private(set) var connectionStatus = "시작 중"
    @Published private(set) var inputMonitoring = PermissionState.notDetermined
    @Published private(set) var inputMonitoringReady = false
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
    var permissionRefreshRequested: (() -> Bool)?
    var permissionResetRequested: (() -> Void)?
    var helperEnabledDidChange: ((Bool) -> Void)?
    var updateCheckRequested: (() -> Void)?
    var launchAtLoginDidChange: ((Bool) -> LaunchAtLoginChangeResult)?

    func resetInputMonitoring() {
        permissionResetRequested?()
    }

    func update(snapshot: SettingsSnapshot) {
        role = snapshot.role
        if !pairingCodeIsDirty {
            pairingCode = snapshot.pairingCode
        }
        connectionStatus = snapshot.connectionStatus
        inputMonitoringReady = snapshot.inputMonitoringReady
        helperEnabled = snapshot.helperEnabled
        currentVersion = snapshot.currentVersion
        canCheckForUpdates = snapshot.canCheckForUpdates
        applyLaunchAtLoginState(snapshot.launchAtLoginState)
    }

    func refreshPermissions(recheckRuntime: Bool = false) {
        if recheckRuntime, let permissionRefreshRequested {
            inputMonitoringReady = permissionRefreshRequested()
        }
        inputMonitoring = AppPermissions.inputMonitoring
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
    var permissionRefreshRequested: (() -> Bool)?
    var permissionResetRequested: (() -> Void)?
    var helperEnabledDidChange: ((Bool) -> Void)?
    var updateCheckRequested: (() -> Void)?
    var launchAtLoginDidChange: ((Bool) -> LaunchAtLoginChangeResult)?

    private let model = SettingsViewModel()

    init() {
        let rootView = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Universal Control Helper 설정"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 680))
        window.minSize = NSSize(width: 560, height: 620)
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
        model.permissionRefreshRequested = { [weak self] in
            self?.permissionRefreshRequested?() ?? false
        }
        model.permissionResetRequested = { [weak self] in
            self?.permissionResetRequested?()
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

    func present(snapshot: SettingsSnapshot, focusPairingCode: Bool = false) {
        model.update(snapshot: snapshot)
        model.refreshPermissions()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        if focusPairingCode, snapshot.role == .target {
            NotificationCenter.default.post(name: .focusPairingCode, object: nil)
        }
    }

    func update(snapshot: SettingsSnapshot) {
        model.update(snapshot: snapshot)
    }

    func refreshPermissionStatus() {
        model.refreshPermissions()
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @FocusState private var pairingCodeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            connectionSection
            if model.role == .source {
                permissionSection
            }
            generalSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 620, idealHeight: 680)
        .onReceive(NotificationCenter.default.publisher(for: .focusPairingCode)) { _ in
            pairingCodeFocused = true
        }
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
                Text("Caps Lock 한/영 전환과 두 Mac의 연결을 관리합니다.")
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
                    .focused($pairingCodeFocused)
                    .onSubmit { model.applyPairingCode() }
                    .accessibilityLabel("페어링 코드")
                    Button("적용") { model.applyPairingCode() }
                        .accessibilityLabel("페어링 코드 적용")
                }
            }
        }
    }

    private var permissionSection: some View {
        GroupBox("입력 권한") {
            VStack(alignment: .leading, spacing: 14) {
                permissionRow(
                    title: "입력 모니터링",
                    detail: inputMonitoringDescription,
                    color: inputMonitoringColor,
                    buttonTitle: "설정 열기"
                ) {
                    AppPermissions.openInputMonitoringSettings()
                }

                Text("Source에서 Caps Lock을 감지할 때만 필요합니다. 스위치가 켜져 있는데 미허용이면 권한 초기화 후 다시 허용하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    if !model.inputMonitoringReady {
                        Button("권한 초기화…", role: .destructive) {
                            model.resetInputMonitoring()
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                    Button {
                        model.refreshPermissions(recheckRuntime: true)
                    } label: {
                        Label("권한 다시 확인", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
            }
            .padding(8)
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

                Divider()

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
            }
            .padding(8)
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        color: Color,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .accessibilityLabel("\(title) 설정 열기")
        }
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

    private var inputMonitoringDescription: String {
        if model.inputMonitoringReady {
            return "사용 가능 · Caps Lock 감지 중"
        }
        switch model.inputMonitoring {
        case .granted:
            return "허용됐지만 감지 시작 실패 · 앱을 다시 실행해 주세요"
        case .denied:
            return "현재 앱에는 미허용 · 허용한 뒤 다시 확인"
        case .notDetermined:
            return "아직 결정되지 않음"
        }
    }

    private var inputMonitoringColor: Color {
        if model.inputMonitoringReady {
            return .green
        }
        switch model.inputMonitoring {
        case .granted:
            return .orange
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }

    private var roleExplanation: String {
        switch model.role {
        case .source:
            return "Caps Lock의 로컬 동작은 유지되고 Target도 함께 전환됩니다."
        case .target:
            return "Source에서 받은 Caps Lock 신호로 ABC와 두벌식을 전환합니다."
        }
    }
}

private extension Notification.Name {
    static let focusPairingCode = Notification.Name("UniversalControlHelper.focusPairingCode")
}
