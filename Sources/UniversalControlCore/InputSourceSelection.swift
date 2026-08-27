import Foundation

public struct InputSourceDescriptor: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum InputSourceState: String, Codable, Equatable, Sendable {
    case abc
    case korean
}

public enum InputSourceSelection {
    public static func state(
        id: String,
        name: String = ""
    ) -> InputSourceState? {
        let normalizedID = id.lowercased()
        let normalizedName = name.lowercased()
        if normalizedID.contains("korean")
            || normalizedID.contains("hangul")
            || normalizedID.contains("2set")
            || normalizedName.contains("두벌식") {
            return .korean
        }
        if id == "com.apple.keylayout.ABC"
            || name.caseInsensitiveCompare("ABC") == .orderedSame {
            return .abc
        }
        return nil
    }

    public static func targetID(
        for state: InputSourceState,
        candidates: [InputSourceDescriptor]
    ) -> String? {
        switch state {
        case .abc:
            return candidates.first { $0.id == "com.apple.keylayout.ABC" }?.id
                ?? candidates.first { $0.name.caseInsensitiveCompare("ABC") == .orderedSame }?.id
        case .korean:
            return candidates.first {
                let id = $0.id.lowercased()
                return id.contains("2setkorean") || id.contains("2sethangul")
            }?.id ?? candidates.first {
                let id = $0.id.lowercased()
                return id.contains("korean") || id.contains("hangul")
            }?.id
        }
    }

    public static func targetID(
        currentID: String,
        candidates: [InputSourceDescriptor]
    ) -> String? {
        let currentState = state(id: currentID)
        let targetState: InputSourceState = currentState == .korean ? .abc : .korean
        return targetID(for: targetState, candidates: candidates)
    }
}
