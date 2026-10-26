import Testing
@testable import BlablaApp

struct InsertOutcomeTests {
    @Test
    func insertedNamesTheTargetApp() {
        let outcome = InsertOutcome.inserted(appName: "TextEdit")
        #expect(outcome.title == "Inserted into TextEdit")
        #expect(outcome.detail == nil)
    }

    @Test
    func copiedExplainsWhyAutoInsertDidNotHappen() {
        let outcome = InsertOutcome.copied(reason: "Auto-insert needs Accessibility permission.")
        #expect(outcome.title == "Copied — press ⌘V to paste")
        #expect(outcome.detail == "Auto-insert needs Accessibility permission.")
        #expect(InsertOutcome.copied(reason: nil).detail == nil)
    }
}
