import Foundation

public struct RelayMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case hello
        case helloAck
        case toggleInputSource
        case setInputSource
    }

    public let kind: Kind
    public let token: String
    public let inputSource: InputSourceState?
    public let protocolVersion: Int?

    public init(
        kind: Kind,
        token: String,
        inputSource: InputSourceState? = nil,
        protocolVersion: Int? = nil
    ) {
        self.kind = kind
        self.token = token
        self.inputSource = inputSource
        self.protocolVersion = protocolVersion
    }

    public static func hello(token: String) -> RelayMessage {
        RelayMessage(kind: .hello, token: token, protocolVersion: RelayProtocol.currentVersion)
    }

    public static func helloAck(token: String) -> RelayMessage {
        RelayMessage(kind: .helloAck, token: token, protocolVersion: RelayProtocol.currentVersion)
    }

    public static func toggleInputSource(token: String) -> RelayMessage {
        RelayMessage(kind: .toggleInputSource, token: token)
    }

    public static func setInputSource(_ inputSource: InputSourceState, token: String) -> RelayMessage {
        RelayMessage(
            kind: .setInputSource,
            token: token,
            inputSource: inputSource,
            protocolVersion: RelayProtocol.currentVersion
        )
    }
}

public enum RelayProtocol {
    /// v3 sends the raw input source id in `setInputSource` (any configured
    /// pair), not just the old abc/korean tag. Peers below this version can't
    /// decode that, so they're kept on the legacy toggle-relay path instead.
    public static let currentVersion = 3

    public static func supportsExplicitInputSourceState(_ peerProtocolVersion: Int) -> Bool {
        peerProtocolVersion >= currentVersion
    }
}

public enum RelayCodec {
    public static func encodeLine(_ message: RelayMessage) throws -> Data {
        var data = try JSONEncoder().encode(message)
        data.append(0x0A)
        return data
    }

    public static func decode(_ data: Data) throws -> RelayMessage {
        try JSONDecoder().decode(RelayMessage.self, from: data)
    }
}

public struct LineFramer: Sendable {
    private var buffer = Data()
    public let maximumFrameSize: Int

    public init(maximumFrameSize: Int = 64 * 1024) {
        self.maximumFrameSize = maximumFrameSize
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        guard buffer.count <= maximumFrameSize else {
            buffer.removeAll(keepingCapacity: false)
            throw FramingError.frameTooLarge
        }

        var frames: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let frame = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if !frame.isEmpty {
                frames.append(frame)
            }
        }
        return frames
    }

    public enum FramingError: Error, Equatable {
        case frameTooLarge
    }
}

public enum PairingCode {
    public static func isValid(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }

    public static func generate() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}
