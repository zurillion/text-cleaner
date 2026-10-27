import AppKit
import XCTest
@testable import TextCleaner

final class TransformationStackTests: XCTestCase {

    private func action(_ kind: TextActionKind) -> TextAction {
        TextAction.all.first { $0.kind == kind }!
    }

    private func model(source: String) -> PopupViewModel {
        let model = PopupViewModel()
        model.sourceAttributed = NSAttributedString(string: source)
        model.isPinned = true
        return model
    }

    func testActionsApplyOnThePreviousResult() {
        let model = model(source: "hello world")
        model.pushAction(action(.uppercase))
        model.pushAction(action(.reverse))
        XCTAssertEqual(model.stackResult.string, "DLROW OLLEH")
        XCTAssertEqual(model.stack.layers.map(\.title), ["UPPERCASE", "Reverse"])
    }

    func testEmptyStackResultIsTheSource() {
        let model = model(source: "hello")
        XCTAssertEqual(model.stackResult.string, "hello")
    }

    func testUndoAndRedo() {
        let model = model(source: "hello world")
        model.pushAction(action(.uppercase))
        model.pushAction(action(.reverse))

        model.undo()
        XCTAssertEqual(model.stackResult.string, "HELLO WORLD")
        XCTAssertTrue(model.stack.canRedo)

        model.redo()
        XCTAssertEqual(model.stackResult.string, "DLROW OLLEH")
        XCTAssertFalse(model.stack.canRedo)

        model.undo()
        model.undo()
        XCTAssertEqual(model.stackResult.string, "hello world")
        model.undo()  // Nothing left: a no-op.
        XCTAssertTrue(model.stack.isEmpty)
    }

    func testPushAfterUndoDropsTheRedoHistory() {
        let model = model(source: "hello")
        model.pushAction(action(.uppercase))
        model.undo()
        model.pushAction(action(.reverse))
        XCTAssertFalse(model.stack.canRedo)
        XCTAssertEqual(model.stackResult.string, "olleh")
    }

    func testEditIsALayerThatLaterActionsBuildOn() {
        let model = model(source: "hello")
        model.pushAction(action(.uppercase))
        model.pushEdit(NSAttributedString(string: "HELLO there"))
        model.pushAction(action(.reverse))
        XCTAssertEqual(model.stackResult.string, "ereht OLLEH")

        model.undo()
        XCTAssertEqual(model.stackResult.string, "HELLO there")
        model.undo()
        XCTAssertEqual(model.stackResult.string, "HELLO")
    }

    func testUppercaseKeepsTheFormattingOfAnEdit() {
        let model = model(source: "hello")
        let bold = NSFont.boldSystemFont(ofSize: 13)
        model.pushEdit(NSAttributedString(string: "hello", attributes: [.font: bold]))
        model.pushAction(action(.uppercase))

        let result = model.stackResult
        XCTAssertEqual(result.string, "HELLO")
        XCTAssertEqual(result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont, bold)
    }

    func testHTMLActionsOnlyWorkAsTheFirstLayer() {
        let model = model(source: "plain flavor")
        model.htmlSource = NSAttributedString(string: "html flavor")

        XCTAssertTrue(model.isAvailable(action(.htmlToPlainText)))
        model.pushAction(action(.htmlToPlainText))
        XCTAssertEqual(model.stackResult.string, "html flavor")

        XCTAssertFalse(model.isAvailable(action(.htmlToRichText)))
        model.pushAction(action(.htmlToRichText))  // Ignored.
        XCTAssertEqual(model.stack.layers.count, 1)
    }

    func testPreviewShowsTheHighlightedActionOnTopOfTheStack() {
        let model = model(source: "hello world")
        model.actions = [action(.uppercase), action(.reverse)]
        model.pushAction(action(.uppercase))

        model.selectedIndex = 1
        XCTAssertEqual(model.currentPreviewAttributed.string, "DLROW OLLEH")
    }

    func testStackStaysVisibleAfterUnpinningUntilEmpty() {
        let model = model(source: "hello")
        XCTAssertTrue(model.showsStack)
        model.pushAction(action(.uppercase))
        model.isPinned = false
        XCTAssertTrue(model.showsStack)

        model.resetStack()
        XCTAssertFalse(model.showsStack)
        XCTAssertFalse(model.isPinned)
    }
}
