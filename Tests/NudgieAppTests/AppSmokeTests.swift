import Testing
import NudgieCore
@testable import Nudgie

@MainActor @Test func appModuleLinks() {
    #expect(NudgieCore.version == "0.1.0")
}
