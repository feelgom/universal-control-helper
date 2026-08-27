import Carbon
import IOKit.hid
import UniversalControlCore

final class PhysicalCapsLockMonitor {
    var onCapsLockPressed: (() -> Void)?

    private var manager: IOHIDManager?

    @discardableResult
    func start() -> Bool {
        guard manager == nil else { return true }
        if AppPermissions.inputMonitoring != .granted {
            AppPermissions.requestInputMonitoring()
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let matches: [[String: Int]] = [[
            kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_Keyboard),
        ]]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            { context, _, _, value in
                guard let context else { return }
                let monitor = Unmanaged<PhysicalCapsLockMonitor>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                monitor.handle(value)
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
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
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard isPhysicalDevice(IOHIDElementGetDevice(element)) else { return }
        guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
              IOHIDElementGetUsage(element) == UInt32(kHIDUsage_KeyboardCapsLock),
              IOHIDValueGetIntegerValue(value) == 1 else {
            return
        }
        onCapsLockPressed?()
    }

    private func isPhysicalDevice(_ device: IOHIDDevice?) -> Bool {
        guard let device else { return false }
        let transport = property(kIOHIDTransportKey as CFString, device: device).lowercased()
        let product = property(kIOHIDProductKey as CFString, device: device).lowercased()
        return !transport.contains("virtual")
            && !product.contains("virtual")
            && !product.contains("universal control")
    }

    private func property(_ key: CFString, device: IOHIDDevice) -> String {
        IOHIDDeviceGetProperty(device, key) as? String ?? ""
    }

    deinit {
        stop()
    }
}

final class InputSourceRelay {
    var send: ((InputSourceState) -> Void)?

    private var monitor: InputSourceMonitor?

    @discardableResult
    func start() -> Bool {
        guard monitor == nil else { return true }
        let monitor = InputSourceMonitor()
        monitor.stateDidChange = { [weak self] state in self?.send?(state) }
        monitor.start()
        self.monitor = monitor
        return true
    }

    func stop() {
        monitor?.stop()
        monitor = nil
    }

    func synchronizeCurrentState() {
        guard let state = InputSourceController.currentState else { return }
        send?(state)
    }
}

final class InputSourceMonitor {
    var stateDidChange: ((InputSourceState) -> Void)?

    private var isStarted = false
    private var lastState: InputSourceState?

    func start() {
        guard !isStarted else { return }
        isStarted = true
        lastState = InputSourceController.currentState
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            inputSourceChangedCallback,
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    func stop() {
        guard isStarted else { return }
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged),
            nil
        )
        isStarted = false
    }

    fileprivate func inputSourceDidChange() {
        guard let state = InputSourceController.currentState, state != lastState else { return }
        lastState = state
        stateDidChange?(state)
    }

    deinit {
        stop()
    }
}

private func inputSourceChangedCallback(
    _: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    _: CFNotificationName?,
    _: UnsafeRawPointer?,
    _: CFDictionary?
) {
    guard let observer else { return }
    let monitor = Unmanaged<InputSourceMonitor>.fromOpaque(observer).takeUnretainedValue()
    monitor.inputSourceDidChange()
}

enum TargetInputInjector {
    static func handle(_ message: RelayMessage) {
        switch message.kind {
        case .toggleInputSource:
            InputSourceController.toggleKoreanAndABC()
        case .setInputSource:
            guard let inputSource = message.inputSource else { return }
            InputSourceController.select(inputSource)
        case .hello, .helloAck:
            break
        }
    }
}

enum InputSourceController {
    static var currentState: InputSourceState? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return InputSourceSelection.state(
            id: identifier(of: current),
            name: localizedName(of: current)
        )
    }

    static func select(_ state: InputSourceState) {
        if currentState == state { return }
        guard let target = inputSource(for: state) else { return }
        TISSelectInputSource(target)
    }

    static func toggleKoreanAndABC() {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        let candidates = inputSources()
        let descriptors = candidates.map(descriptor)
        guard let targetID = InputSourceSelection.targetID(
            currentID: identifier(of: current),
            candidates: descriptors
        ), let target = candidates.first(where: { identifier(of: $0) == targetID }) else {
            return
        }
        TISSelectInputSource(target)
    }

    private static func inputSource(for state: InputSourceState) -> TISInputSource? {
        let candidates = inputSources()
        let descriptors = candidates.map(descriptor)
        guard let targetID = InputSourceSelection.targetID(for: state, candidates: descriptors) else {
            return nil
        }
        return candidates.first { identifier(of: $0) == targetID }
    }

    private static func inputSources() -> [TISInputSource] {
        guard let unmanaged = TISCreateInputSourceList(nil, false) else { return [] }
        return unmanaged.takeRetainedValue() as! [TISInputSource]
    }

    private static func descriptor(_ source: TISInputSource) -> InputSourceDescriptor {
        InputSourceDescriptor(id: identifier(of: source), name: localizedName(of: source))
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
