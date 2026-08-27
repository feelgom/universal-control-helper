import Carbon
import IOKit.hid
import UniversalControlCore

final class InputRelay {
    var send: ((RelayMessage) -> Void)?

    private let tokenProvider: () -> String
    private var physicalMonitor: PhysicalInputMonitor?

    init(tokenProvider: @escaping () -> String) {
        self.tokenProvider = tokenProvider
    }

    @discardableResult
    func start() -> Bool {
        guard physicalMonitor == nil else { return true }
        // IOHIDCheckAccess can lag behind System Settings or report a stale
        // ad-hoc build entry. Request access when needed, but let the actual
        // IOHIDManager open decide whether this process can monitor input.
        if AppPermissions.inputMonitoring != .granted {
            AppPermissions.requestInputMonitoring()
        }

        let monitor = PhysicalInputMonitor()
        monitor.onCapsLockPressed = { [weak self] in
            guard let self else { return }
            self.send?(.toggleInputSource(token: self.tokenProvider()))
        }
        physicalMonitor = monitor
        guard monitor.start() else {
            physicalMonitor = nil
            return false
        }
        return true
    }

    func stop() {
        physicalMonitor?.stop()
        physicalMonitor = nil
    }
}

final class PhysicalInputMonitor {
    var onCapsLockPressed: (() -> Void)?

    private var manager: IOHIDManager?

    func start() -> Bool {
        guard manager == nil else { return true }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let matches: [[String: Int]] = [
            [
                kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_Keyboard),
            ],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            { context, _, _, value in
                guard let context else { return }
                let monitor = Unmanaged<PhysicalInputMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.handle(value)
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            self.manager = nil
            return false
        }
        return true
    }

    func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard isPhysicalDevice(IOHIDElementGetDevice(element)) else { return }
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)

        if page == UInt32(kHIDPage_KeyboardOrKeypad),
           usage == UInt32(kHIDUsage_KeyboardCapsLock),
           integerValue == 1 {
            onCapsLockPressed?()
        }
    }

    private func isPhysicalDevice(_ device: IOHIDDevice?) -> Bool {
        guard let device else { return false }
        let transport = property(kIOHIDTransportKey as CFString, device: device).lowercased()
        let product = property(kIOHIDProductKey as CFString, device: device).lowercased()
        if transport.contains("virtual") || product.contains("virtual") || product.contains("universal control") {
            return false
        }
        return true
    }

    private func property(_ key: CFString, device: IOHIDDevice) -> String {
        IOHIDDeviceGetProperty(device, key) as? String ?? ""
    }
}

enum TargetInputInjector {
    static func handle(_ message: RelayMessage) {
        switch message.kind {
        case .toggleInputSource:
            InputSourceSwitcher.toggleKoreanAndABC()
        case .hello, .helloAck:
            break
        }
    }

}

enum InputSourceSwitcher {
    static func toggleKoreanAndABC() {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        let currentID = identifier(of: current)

        guard let unmanaged = TISCreateInputSourceList(nil, false) else { return }
        let candidates = unmanaged.takeRetainedValue() as! [TISInputSource]
        let descriptors = candidates.map {
            InputSourceDescriptor(id: identifier(of: $0), name: localizedName(of: $0))
        }
        guard let targetID = InputSourceSelection.targetID(currentID: currentID, candidates: descriptors),
              let target = candidates.first(where: { identifier(of: $0) == targetID }) else { return }
        TISSelectInputSource(target)
    }

    private static func identifier(of source: TISInputSource) -> String {
        stringProperty(kTISPropertyInputSourceID, of: source)
    }

    private static func localizedName(of source: TISInputSource) -> String {
        stringProperty(kTISPropertyLocalizedName, of: source)
    }

    private static func stringProperty(_ key: CFString, of source: TISInputSource) -> String {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
