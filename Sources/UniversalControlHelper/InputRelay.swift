import AppKit
import ApplicationServices
import Carbon
import IOKit.hid
import UniversalControlCore

final class InputRelay {
    var relayActiveDidChange: ((Bool) -> Void)?
    var send: ((RelayMessage) -> Void)?

    private let tokenProvider: () -> String
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var physicalMonitor: PhysicalInputMonitor?

    var isRelayActive = false {
        didSet {
            guard oldValue != isRelayActive else { return }
            relayActiveDidChange?(isRelayActive)
        }
    }

    init(tokenProvider: @escaping () -> String) {
        self.tokenProvider = tokenProvider
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let monitor = PhysicalInputMonitor()
        monitor.onCapsLockPressed = { [weak self] in
            guard let self, self.isRelayActive else { return }
            self.send?(.toggleInputSource(token: self.tokenProvider()))
        }
        physicalMonitor = monitor
        monitor.start()

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let relay = Unmanaged<InputRelay>.fromOpaque(context).takeUnretainedValue()
                return relay.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        physicalMonitor?.stop()
        physicalMonitor = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown,
           event.getIntegerValueField(.keyboardEventKeycode) == 32,
           event.flags.intersection([.maskCommand, .maskAlternate, .maskControl]) == [.maskCommand, .maskAlternate, .maskControl] {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRelayActive.toggle()
            }
            return nil
        }

        if type == .flagsChanged, event.getIntegerValueField(.keyboardEventKeycode) == 57 {
            return isRelayActive ? nil : Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }
}

final class PhysicalInputMonitor {
    var onCapsLockPressed: (() -> Void)?

    private var manager: IOHIDManager?

    func start() {
        guard manager == nil else { return }
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
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
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

func requestAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
