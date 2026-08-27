import XCTest
@testable import UniversalControlHelper

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
            launchAtLoginState: .disabled
        )
    }
}
