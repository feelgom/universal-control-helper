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
        let original = RelayMessage.setInputSource("com.apple.inputmethod.Korean.2SetKorean", token: "123456")
        let encoded = try RelayCodec.encodeLine(original)
        let decoded = try RelayCodec.decode(encoded.dropLast())

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.protocolVersion, RelayProtocol.currentVersion)
        XCTAssertEqual(decoded.inputSource, "com.apple.inputmethod.Korean.2SetKorean")
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

    func testLegacyPeerDoesNotReceiveDuplicateStateSynchronization() {
        XCTAssertFalse(RelayProtocol.supportsExplicitInputSourceState(1))
        XCTAssertFalse(RelayProtocol.supportsExplicitInputSourceState(2))
        XCTAssertTrue(RelayProtocol.supportsExplicitInputSourceState(RelayProtocol.currentVersion))
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

    func testInputSourceSelectionTogglesDefaultPair() {
        XCTAssertEqual(
            InputSourceSelection.toggleTargetID(
                currentID: "com.apple.inputmethod.Korean.2SetKorean",
                pair: .defaultPair
            ),
            "com.apple.keylayout.ABC"
        )
        XCTAssertEqual(
            InputSourceSelection.toggleTargetID(currentID: "com.apple.keylayout.ABC", pair: .defaultPair),
            "com.apple.inputmethod.Korean.2SetKorean"
        )
    }

    func testInputSourceSelectionTogglesArbitraryConfiguredPair() {
        let pair = InputSourcePair(
            primaryID: "com.apple.keylayout.US",
            secondaryID: "com.apple.inputmethod.Japanese.FullWidthRoman"
        )
        XCTAssertEqual(
            InputSourceSelection.toggleTargetID(currentID: "com.apple.keylayout.US", pair: pair),
            "com.apple.inputmethod.Japanese.FullWidthRoman"
        )
        XCTAssertEqual(
            InputSourceSelection.toggleTargetID(currentID: "com.apple.inputmethod.Japanese.FullWidthRoman", pair: pair),
            "com.apple.keylayout.US"
        )
        // Unknown/nil current state falls back to the primary source.
        XCTAssertEqual(InputSourceSelection.toggleTargetID(currentID: nil, pair: pair), pair.primaryID)
        XCTAssertEqual(
            InputSourceSelection.toggleTargetID(currentID: "com.apple.CharacterPaletteIM", pair: pair),
            pair.primaryID
        )
    }

    func testInputSourceSelectionResolvesByExactID() {
        let sources = [
            InputSourceDescriptor(id: "com.apple.keylayout.ABC", name: "ABC"),
            InputSourceDescriptor(id: "com.apple.inputmethod.Korean.2SetKorean", name: "두벌식"),
        ]
        XCTAssertEqual(InputSourceSelection.resolve(id: "com.apple.keylayout.ABC", candidates: sources), sources[0])
        XCTAssertNil(InputSourceSelection.resolve(id: "com.apple.CharacterPaletteIM", candidates: sources))
    }
}
