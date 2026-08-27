import AppKit
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool { self == .enabled }
}

struct LaunchAtLoginChangeResult: Equatable {
    let state: LaunchAtLoginState
    let message: String?
}

enum LaunchAtLogin {
    static var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    static func setEnabled(_ enabled: Bool) -> LaunchAtLoginChangeResult {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return LaunchAtLoginChangeResult(
                state: state,
                message: "자동 실행 설정을 변경하지 못했습니다: \(error.localizedDescription)"
            )
        }

        let currentState = state
        let message: String?
        switch currentState {
        case .requiresApproval:
            message = "macOS 설정에서 Universal Control Helper의 자동 실행을 허용해 주세요."
        case .unavailable:
            message = "앱을 응용 프로그램 폴더에 설치한 뒤 다시 시도해 주세요."
        case .enabled, .disabled:
            message = nil
        }
        return LaunchAtLoginChangeResult(state: currentState, message: message)
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
