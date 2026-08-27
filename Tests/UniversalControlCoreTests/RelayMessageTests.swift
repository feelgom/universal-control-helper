import XCTest
@testable import UniversalControlCore

final class RelayMessageTests: XCTestCase {
    func testRoundTripToggleMessage() throws {
        let original = RelayMessage.toggleInputSource(token: "123456")
        let encoded = try RelayCodec.encodeLine(original)
        let decoded = try RelayCodec.decode(encoded.dropLast())
        XCTAssertEqual(decoded, original)
    }

    func testRoundTripInputSourceStateMessage() throws {
        let original = RelayMessage.setInputSource(.korean, token: "123456")
        let encoded = try RelayCodec.encodeLine(original)
        let decoded = try RelayCodec.decode(encoded.dropLast())

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.protocolVersion, 2)
        XCTAssertEqual(decoded.inputSource, .korean)
    }

    func testHandshakeRemainsDecodableByLegacyPeer() throws {
        struct LegacyMessage: Decodable {
            let kind: String
            let token: String
        }

        let encoded = try RelayCodec.encodeLine(.hello(token: "123456"))
        let decoded = try JSONDecoder().decode(LegacyMessage.self, from: encoded.dropLast())

        XCTAssertEqual(decoded.kind, "hello")
        XCTAssertEqual(decoded.token, "123456")
    }

    func testInputSourceMessageFallsBackForLegacyPeer() {
        XCTAssertEqual(
            RelayProtocol.inputSourceMessage(.korean, token: "123456", peerProtocolVersion: 1),
            .toggleInputSource(token: "123456")
        )
        XCTAssertEqual(
            RelayProtocol.inputSourceMessage(.abc, token: "123456", peerProtocolVersion: 2),
            .setInputSource(.abc, token: "123456")
        )
    }

    func testFramerHandlesSplitAndCombinedPackets() throws {
        let first = try RelayCodec.encodeLine(.hello(token: "111111"))
        let second = try RelayCodec.encodeLine(.toggleInputSource(token: "111111"))
        let joined = first + second
        let split = joined.count / 2
        var framer = LineFramer()

        let initial = try framer.append(joined.prefix(split))
        let remaining = try framer.append(joined.suffix(from: split))

        XCTAssertLessThanOrEqual(initial.count, 1)
        XCTAssertEqual(initial.count + remaining.count, 2)
        XCTAssertEqual(try RelayCodec.decode((initial + remaining)[0]).kind, .hello)
        XCTAssertEqual(try RelayCodec.decode((initial + remaining)[1]).kind, .toggleInputSource)
    }

    func testFramerRejectsOversizedFrame() {
        var framer = LineFramer(maximumFrameSize: 4)
        XCTAssertThrowsError(try framer.append(Data(repeating: 0x41, count: 5))) { error in
            XCTAssertEqual(error as? LineFramer.FramingError, .frameTooLarge)
        }
    }

    func testPairingCodeValidation() {
        XCTAssertTrue(PairingCode.isValid("012345"))
        XCTAssertFalse(PairingCode.isValid("12345"))
        XCTAssertFalse(PairingCode.isValid("12A456"))
        XCTAssertEqual(PairingCode.generate().count, 6)
    }

    func testInputSourceSelectionTogglesKoreanAndABC() {
        let sources = [
            InputSourceDescriptor(id: "com.apple.keylayout.ABC", name: "ABC"),
            InputSourceDescriptor(id: "com.apple.inputmethod.Korean.2SetKorean", name: "두벌식"),
        ]
        XCTAssertEqual(
            InputSourceSelection.targetID(currentID: "com.apple.inputmethod.Korean.2SetKorean", candidates: sources),
            "com.apple.keylayout.ABC"
        )
        XCTAssertEqual(
            InputSourceSelection.targetID(currentID: "com.apple.keylayout.ABC", candidates: sources),
            "com.apple.inputmethod.Korean.2SetKorean"
        )
    }

    func testInputSourceSelectionClassifiesAndSelectsExplicitState() {
        let sources = [
            InputSourceDescriptor(id: "com.apple.keylayout.ABC", name: "ABC"),
            InputSourceDescriptor(id: "com.apple.inputmethod.Korean.2SetKorean", name: "두벌식"),
        ]

        XCTAssertEqual(InputSourceSelection.state(id: sources[0].id, name: sources[0].name), .abc)
        XCTAssertEqual(InputSourceSelection.state(id: sources[1].id, name: sources[1].name), .korean)
        XCTAssertNil(InputSourceSelection.state(id: "com.apple.CharacterPaletteIM", name: "이모티콘"))
        XCTAssertEqual(
            InputSourceSelection.targetID(for: .abc, candidates: sources),
            "com.apple.keylayout.ABC"
        )
        XCTAssertEqual(
            InputSourceSelection.targetID(for: .korean, candidates: sources),
            "com.apple.inputmethod.Korean.2SetKorean"
        )
    }
}
