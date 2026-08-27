import Foundation

public struct RelayMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case hello
        case helloAck
        case toggleInputSource
    }

    public let kind: Kind
    public let token: String

    public init(kind: Kind, token: String) {
        self.kind = kind
        self.token = token
    }

    public static func hello(token: String) -> RelayMessage {
        RelayMessage(kind: .hello, token: token)
    }

    public static func helloAck(token: String) -> RelayMessage {
        RelayMessage(kind: .helloAck, token: token)
    }

    public static func toggleInputSource(token: String) -> RelayMessage {
        RelayMessage(kind: .toggleInputSource, token: token)
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
