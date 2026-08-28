import AppKit
import SwiftUI
import UniversalControlCore

struct SettingsSnapshot {
    let role: ComputerRole
    let pairingCode: String
    let connectionStatus: String
    let inputMonitoringReady: Bool
    let helperEnabled: Bool
    let currentVersion: String
    let canCheckForUpdates: Bool
    let launchAtLoginState: LaunchAtLoginState
    let availableInputSources: [InputSourceDescriptor]
    let inputSourcePair: InputSourcePair
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
    @Published private(set) var availableInputSources: [InputSourceDescriptor] = []
    @Published private(set) var primaryInputSourceID = InputSourcePair.defaultPair.primaryID
    @Published private(set) var secondaryInputSourceID = InputSourcePair.defaultPair.secondaryID

    var roleDidChange: ((ComputerRole) -> Void)?
    var pairingCodeDidChange: ((String) -> Bool)?
    var pairingCodeRegenerationRequested: (() -> String)?
    var permissionRefreshRequested: (() -> Bool)?
    var permissionResetRequested: (() -> Void)?
    var helperEnabledDidChange: ((Bool) -> Void)?
    var updateCheckRequested: (() -> Void)?
    var launchAtLoginDidChange: ((Bool) -> LaunchAtLoginChangeResult)?
    var inputSourcePairDidChange: ((InputSourcePair) -> Void)?

    func update(snapshot: SettingsSnapshot) {
        role = snapshot.role
        if !pairingCodeIsDirty {
            pairingCode = snapshot.pairingCode
        }
        connectionStatus = snapshot.connectionStatus
        inputMonitoringReady = snapshot.inputMonitoringReady
        inputMonitoring = AppPermissions.inputMonitoring
        helperEnabled = snapshot.helperEnabled
        currentVersion = snapshot.currentVersion
        canCheckForUpdates = snapshot.canCheckForUpdates
        applyLaunchAtLoginState(snapshot.launchAtLoginState)
        availableInputSources = snapshot.availableInputSources
        primaryInputSourceID = snapshot.inputSourcePair.primaryID
        secondaryInputSourceID = snapshot.inputSourcePair.secondaryID
    }

    func selectPrimaryInputSource(_ id: String) {
        primaryInputSourceID = id
        inputSourcePairDidChange?(InputSourcePair(primaryID: id, secondaryID: secondaryInputSourceID))
    }

    func selectSecondaryInputSource(_ id: String) {
        secondaryInputSourceID = id
        inputSourcePairDidChange?(InputSourcePair(primaryID: primaryInputSourceID, secondaryID: id))
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

    func refreshInputMonitoring() {
        if let permissionRefreshRequested {
            inputMonitoringReady = permissionRefreshRequested()
        }
        inputMonitoring = AppPermissions.inputMonitoring
    }

    func resetInputMonitoring() {
        permissionResetRequested?()
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
    var inputSourcePairDidChange: ((InputSourcePair) -> Void)?
    var windowDidClose: (() -> Void)?

    private let model = SettingsViewModel()

    init() {
        let rootView = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Universal Control Helper 설정"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 870))
        window.minSize = NSSize(width: 560, height: 810)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        model.roleDidChange = { [weak self] role in
            self?.resize(for: role)
            self?.roleDidChange?(role)
        }
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
        model.inputSourcePairDidChange = { [weak self] pair in
            self?.inputSourcePairDidChange?(pair)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(snapshot: SettingsSnapshot) {
        model.update(snapshot: snapshot)
        resize(for: snapshot.role)
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

    private func resize(for role: ComputerRole) {
        let height: CGFloat = role == .source ? 870 : 740
        window?.minSize = NSSize(width: 560, height: role == .source ? 810 : 690)
        window?.setContentSize(NSSize(width: 600, height: height))
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            generalSection
            inputSourceSection
            connectionSection
            if model.role == .source {
                inputPermissionSection
            }
            softwareUpdateSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(
            minWidth: 560,
            idealWidth: 600,
            minHeight: model.role == .source ? 810 : 690,
            idealHeight: model.role == .source ? 870 : 740
        )
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

    private var inputSourceSection: some View {
        GroupBox("전환할 입력 소스") {
            VStack(alignment: .leading, spacing: 14) {
                Picker(
                    "입력 소스 A",
                    selection: Binding(
                        get: { model.primaryInputSourceID },
                        set: { model.selectPrimaryInputSource($0) }
                    )
                ) {
                    ForEach(model.availableInputSources, id: \.id) { source in
                        Text(source.name).tag(source.id)
                    }
                }

                Picker(
                    "입력 소스 B",
                    selection: Binding(
                        get: { model.secondaryInputSourceID },
                        set: { model.selectSecondaryInputSource($0) }
                    )
                ) {
                    ForEach(model.availableInputSources, id: \.id) { source in
                        Text(source.name).tag(source.id)
                    }
                }

                Text("Caps Lock을 누르면 이 두 입력 소스를 번갈아 전환합니다. 두 Mac에 같은 두 입력 소스가 설치되어 있어야 합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
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

    private var inputPermissionSection: some View {
        GroupBox("입력 권한 · Source만 필요") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(model.inputMonitoringReady ? Color.green : Color.red)
                        .frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("입력 모니터링")
                            .fontWeight(.medium)
                        Text(inputMonitoringDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("설정 열기") {
                        AppPermissions.openInputMonitoringSettings()
                    }
                    .accessibilityLabel("입력 모니터링 설정 열기")
                }

                Text("스위치가 켜져 있는데도 미허용이면 권한 항목을 재등록하세요. 목록에 앱이 자동으로 나타나지 않으면 +를 눌러 이 앱을 직접 추가해야 합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    if !model.inputMonitoringReady {
                        Button("권한 항목 재등록…", role: .destructive) {
                            model.resetInputMonitoring()
                        }
                        .controlSize(.small)

                        Button("앱 위치 보기") {
                            AppPermissions.revealCurrentApplication()
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                    Button {
                        model.refreshInputMonitoring()
                    } label: {
                        Label("권한 다시 확인", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
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

    private var inputMonitoringDescription: String {
        if model.inputMonitoringReady {
            return "사용 가능 · 물리 Caps Lock 감지 중"
        }
        switch model.inputMonitoring {
        case .granted:
            return "권한은 허용됐지만 감지를 시작하지 못했습니다. 앱을 다시 실행해 주세요."
        case .denied:
            return "현재 빌드에는 미허용 · 설정에서 허용하거나 권한 항목을 재등록하세요."
        case .notDetermined:
            return "아직 허용되지 않음 · 설정에서 입력 모니터링을 허용하세요."
        }
    }

    private var roleExplanation: String {
        switch model.role {
        case .source:
            return "물리 Caps Lock을 Target에 전달하고 ABC/두벌식 상태도 자동으로 맞춥니다."
        case .target:
            return "Source에서 선택한 ABC/두벌식 상태를 그대로 적용합니다."
        }
    }
}
