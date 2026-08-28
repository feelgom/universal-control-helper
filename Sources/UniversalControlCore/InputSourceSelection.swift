import Foundation

public struct InputSourceDescriptor: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A macOS input source identifier (for example `com.apple.keylayout.ABC`),
/// sent over the relay as-is so Target can select the exact source Source is on.
public typealias InputSourceState = String

/// Two input sources Caps Lock toggles between. Defaults to the original
/// ABC ↔ 두벌식 pair so existing installs keep working unconfigured.
public struct InputSourcePair: Equatable, Sendable {
    public let primaryID: String
    public let secondaryID: String

    public init(primaryID: String, secondaryID: String) {
        self.primaryID = primaryID
        self.secondaryID = secondaryID
    }

    public static let defaultPair = InputSourcePair(
        primaryID: "com.apple.keylayout.ABC",
        secondaryID: "com.apple.inputmethod.Korean.2SetKorean"
    )
}

public enum InputSourceSelection {
    /// The other source in `pair` relative to `currentID`. Falls back to
    /// `primaryID` when the current source isn't part of the configured pair.
    public static func toggleTargetID(currentID: String?, pair: InputSourcePair) -> String {
        currentID == pair.primaryID ? pair.secondaryID : pair.primaryID
    }

    public static func resolve(id: String, candidates: [InputSourceDescriptor]) -> InputSourceDescriptor? {
        candidates.first { $0.id == id }
    }
}
