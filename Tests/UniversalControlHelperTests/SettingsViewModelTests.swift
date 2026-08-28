import XCTest
@testable import UniversalControlHelper
import UniversalControlCore

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testUnsavedPairingCodeSurvivesStatusRefresh() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))

        model.editPairingCode("654")
        model.update(snapshot: snapshot(pairingCode: "123456", status: "연결됨"))

        XCTAssertEqual(model.pairingCode, "654")
    }

    func testInvalidPairingCodeShowsValidationFeedback() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))
        model.pairingCodeDidChange = { _ in false }

        model.editPairingCode("123")
        model.applyPairingCode()

        XCTAssertFalse(model.pairingCodeIsValid)
        XCTAssertEqual(model.pairingCodeFeedback, "숫자 6자리를 정확히 입력해 주세요.")
        XCTAssertEqual(model.pairingCode, "123")
    }

    func testAppliedPairingCodeAcceptsFutureSnapshots() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))
        model.pairingCodeDidChange = { $0 == "654321" }

        model.editPairingCode("654321")
        model.applyPairingCode()
        model.update(snapshot: snapshot(pairingCode: "111111"))

        XCTAssertTrue(model.pairingCodeIsValid)
        XCTAssertEqual(model.pairingCode, "111111")
    }

    func testSourceCanRegeneratePairingCode() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))
        model.pairingCodeRegenerationRequested = { "654321" }

        model.regeneratePairingCode()

        XCTAssertEqual(model.pairingCode, "654321")
        XCTAssertEqual(
            model.pairingCodeFeedback,
            "새 코드를 생성했습니다. Target Mac에 입력해 주세요."
        )
    }

    func testUpdateCheckInvokesCallback() {
        let model = SettingsViewModel()
        var updateCheckRequested = false
        model.updateCheckRequested = { updateCheckRequested = true }

        model.checkForUpdates()

        XCTAssertTrue(updateCheckRequested)
    }

    func testPermissionRefreshUsesPhysicalMonitorResult() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))
        model.permissionRefreshRequested = { true }

        model.refreshInputMonitoring()

        XCTAssertTrue(model.inputMonitoringReady)
    }

    func testPermissionResetInvokesRecoveryCallback() {
        let model = SettingsViewModel()
        var resetRequested = false
        model.permissionResetRequested = { resetRequested = true }

        model.resetInputMonitoring()

        XCTAssertTrue(resetRequested)
    }

    func testHelperEnabledInvokesCallback() {
        let model = SettingsViewModel()
        var requestedValue: Bool?
        model.helperEnabledDidChange = { requestedValue = $0 }

        model.setHelperEnabled(false)

        XCTAssertFalse(model.helperEnabled)
        XCTAssertEqual(requestedValue, false)
    }

    func testLaunchAtLoginUsesActualResult() {
        let model = SettingsViewModel()
        model.launchAtLoginDidChange = { requested in
            XCTAssertTrue(requested)
            return LaunchAtLoginChangeResult(state: .requiresApproval, message: "승인 필요")
        }

        model.setLaunchAtLogin(true)

        XCTAssertFalse(model.launchAtLoginEnabled)
        XCTAssertTrue(model.launchAtLoginRequiresApproval)
        XCTAssertEqual(model.launchAtLoginFeedback, "승인 필요")
    }

    func testSelectingInputSourcesInvokesCallbackWithUpdatedPair() {
        let model = SettingsViewModel()
        model.update(snapshot: snapshot(pairingCode: "123456"))
        var reportedPairs: [InputSourcePair] = []
        model.inputSourcePairDidChange = { reportedPairs.append($0) }

        model.selectPrimaryInputSource("com.apple.keylayout.US")
        model.selectSecondaryInputSource("com.apple.inputmethod.Japanese.FullWidthRoman")

        XCTAssertEqual(model.primaryInputSourceID, "com.apple.keylayout.US")
        XCTAssertEqual(model.secondaryInputSourceID, "com.apple.inputmethod.Japanese.FullWidthRoman")
        XCTAssertEqual(reportedPairs.count, 2)
        XCTAssertEqual(reportedPairs[0].primaryID, "com.apple.keylayout.US")
        XCTAssertEqual(reportedPairs[0].secondaryID, InputSourcePair.defaultPair.secondaryID)
        XCTAssertEqual(reportedPairs[1].secondaryID, "com.apple.inputmethod.Japanese.FullWidthRoman")
    }

    private func snapshot(
        pairingCode: String,
        status: String = "대상 Mac 검색 중"
    ) -> SettingsSnapshot {
        SettingsSnapshot(
            role: .source,
            pairingCode: pairingCode,
            connectionStatus: status,
            inputMonitoringReady: false,
            helperEnabled: true,
            currentVersion: "1.5.3",
            canCheckForUpdates: true,
            launchAtLoginState: .disabled,
            availableInputSources: [
                InputSourceDescriptor(id: "com.apple.keylayout.ABC", name: "ABC"),
                InputSourceDescriptor(id: "com.apple.inputmethod.Korean.2SetKorean", name: "두벌식"),
            ],
            inputSourcePair: .defaultPair
        )
    }
}
