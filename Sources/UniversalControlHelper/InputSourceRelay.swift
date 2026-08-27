import Carbon
import UniversalControlCore

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
