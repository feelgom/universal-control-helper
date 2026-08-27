import AppKit
import ApplicationServices
import IOKit.hid

enum PermissionState {
    case granted
    case denied
    case notDetermined
}

enum AppPermissions {
    static var inputMonitoring: PermissionState {
        let hidAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if hidAccess == kIOHIDAccessTypeGranted || CGPreflightListenEventAccess() {
            return .granted
        }

        switch hidAccess {
        case kIOHIDAccessTypeDenied:
            return .denied
        default:
            return .notDetermined
        }
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        if inputMonitoring == .granted {
            return true
        }
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return inputMonitoring == .granted
    }

    static func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
