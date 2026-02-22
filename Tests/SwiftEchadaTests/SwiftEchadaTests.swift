import Testing
@testable import SwiftEchada

@Test func versionIsSet() {
    #expect(!SwiftEchada.version.isEmpty)
}
