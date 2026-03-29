import XCTest
@testable import Raven

final class ViewResolverTests: XCTestCase {

    // MARK: - Text Resolution

    func testTextResolvesWithContent() {
        let text = Text("Hello")
        let node = ViewResolver.resolve(text, path: "root")

        XCTAssertEqual(node.text, "Hello")
        XCTAssertEqual(node.accessibilityRole, .text)
    }

    // MARK: - Stack Resolution

    func testVStackResolvesVertical() {
        let stack = VStack {
            Text("A")
            Text("B")
        }
        let node = ViewResolver.resolve(stack, path: "root")

        XCTAssertEqual(node.stackAxis, .vertical)
        XCTAssertEqual(node.children.count, 2)
    }

    func testHStackResolvesHorizontal() {
        let stack = HStack {
            Text("A")
            Text("B")
        }
        let node = ViewResolver.resolve(stack, path: "root")

        XCTAssertEqual(node.stackAxis, .horizontal)
        XCTAssertEqual(node.children.count, 2)
    }

    // MARK: - Spacer

    func testSpacerIsFlexible() {
        let spacer = Spacer()
        let node = ViewResolver.resolve(spacer, path: "root")

        XCTAssertTrue(node.isFlexible)
    }

    // MARK: - View Modifiers

    func testPaddingModifier() {
        let view = Text("Padded").padding(16)
        let node = ViewResolver.resolve(view, path: "root")

        XCTAssertEqual(node.padding.top, 16)
        XCTAssertEqual(node.padding.leading, 16)
        XCTAssertEqual(node.padding.bottom, 16)
        XCTAssertEqual(node.padding.trailing, 16)
    }

    func testFixedFrameModifier() {
        let view = Text("Fixed").frame(width: 200, height: 100)
        let node = ViewResolver.resolve(view, path: "root")

        XCTAssertEqual(node.fixedWidth, 200)
        XCTAssertEqual(node.fixedHeight, 100)
    }

    func testCornerRadiusModifier() {
        let view = Text("Round").cornerRadius(8)
        let node = ViewResolver.resolve(view, path: "root")

        XCTAssertEqual(node.cornerRadius, 8)
    }
}
