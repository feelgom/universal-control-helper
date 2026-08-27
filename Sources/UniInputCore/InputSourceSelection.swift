import Foundation

public struct InputSourceDescriptor: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum InputSourceSelection {
    public static func targetID(
        currentID: String,
        candidates: [InputSourceDescriptor]
    ) -> String? {
        let current = currentID.lowercased()
        let currentIsKorean = current.contains("korean") || current.contains("hangul") || current.contains("2set")

        if currentIsKorean {
            return candidates.first { $0.id == "com.apple.keylayout.ABC" }?.id
                ?? candidates.first { $0.name.caseInsensitiveCompare("ABC") == .orderedSame }?.id
        }

        return candidates.first {
            let id = $0.id.lowercased()
            return id.contains("2setkorean") || id.contains("2sethangul")
        }?.id ?? candidates.first {
            let id = $0.id.lowercased()
            return id.contains("korean") || id.contains("hangul")
        }?.id
    }
}
