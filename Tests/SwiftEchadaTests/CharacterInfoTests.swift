import Foundation
import Testing
@testable import SwiftEchada

@Suite("CharacterInfo Tests")
struct CharacterInfoTests {

    @Test func jsonRoundTrip() throws {
        let info = CharacterInfo(name: "NARRATOR", description: "The main narrator")
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(CharacterInfo.self, from: data)
        #expect(decoded == info)
    }

    @Test func jsonRoundTripNilDescription() throws {
        let info = CharacterInfo(name: "BOB", description: nil)
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(CharacterInfo.self, from: data)
        #expect(decoded == info)
        #expect(decoded.description == nil)
    }

    @Test func decodesFromJSON() throws {
        let json = """
            {"name": "ALICE", "description": "A curious girl"}
            """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(CharacterInfo.self, from: data)
        #expect(info.name == "ALICE")
        #expect(info.description == "A curious girl")
    }

    @Test func decodesWithoutDescription() throws {
        let json = """
            {"name": "ALICE"}
            """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(CharacterInfo.self, from: data)
        #expect(info.name == "ALICE")
        #expect(info.description == nil)
    }
}
