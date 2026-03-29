import XCTest
@testable import Raven

final class AccessibilityTests: XCTestCase {

    // MARK: - Tree Generation

    func testButtonNodeProducesAccessibilityElement() {
        let node = LayoutNode()
        node.accessibilityRole = .button
        node.accessibilityLabel = "Submit"
        node.x = 10; node.y = 20; node.width = 100; node.height = 40

        let element = AccessibilityCollector.collect(root: node)

        XCTAssertNotNil(element)
        XCTAssertEqual(element?.role, .button)
        XCTAssertEqual(element?.label, "Submit")
    }

    func testHiddenNodeExcluded() {
        let node = LayoutNode()
        node.accessibilityRole = .button
        node.accessibilityLabel = "Hidden"
        node.isAccessibilityHidden = true

        let element = AccessibilityCollector.collect(root: node)
        XCTAssertNil(element)
    }

    func testNoneRoleWithNoChildrenExcluded() {
        let node = LayoutNode()
        node.accessibilityRole = .none

        let element = AccessibilityCollector.collect(root: node)
        XCTAssertNil(element)
    }

    func testNoneRoleWithSingleChildBubblesUp() {
        let container = LayoutNode()
        container.accessibilityRole = .none

        let button = LayoutNode()
        button.accessibilityRole = .button
        button.accessibilityLabel = "OK"

        container.children = [button]

        let element = AccessibilityCollector.collect(root: container)

        // The single child should bubble up
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.role, .button)
        XCTAssertEqual(element?.label, "OK")
    }

    func testNoneRoleWithMultipleChildrenWrapsInGroup() {
        let container = LayoutNode()
        container.accessibilityRole = .none

        let btn1 = LayoutNode()
        btn1.accessibilityRole = .button
        btn1.accessibilityLabel = "A"

        let btn2 = LayoutNode()
        btn2.accessibilityRole = .button
        btn2.accessibilityLabel = "B"

        container.children = [btn1, btn2]

        let element = AccessibilityCollector.collect(root: container)

        XCTAssertNotNil(element)
        XCTAssertEqual(element?.role, .group)
        XCTAssertEqual(element?.children.count, 2)
    }

    func testNestedTreeStructure() {
        let root = LayoutNode()
        root.accessibilityRole = .window
        root.x = 0; root.y = 0; root.width = 800; root.height = 600

        let nav = LayoutNode()
        nav.accessibilityRole = .navigation

        let btn = LayoutNode()
        btn.accessibilityRole = .button
        btn.accessibilityLabel = "Home"
        btn.x = 10; btn.y = 10; btn.width = 80; btn.height = 30

        nav.children = [btn]
        root.children = [nav]

        let element = AccessibilityCollector.collect(root: root)

        XCTAssertNotNil(element)
        XCTAssertEqual(element?.role, .window)
        XCTAssertEqual(element?.children.count, 1)
        XCTAssertEqual(element?.children.first?.role, .navigation)
        XCTAssertEqual(element?.children.first?.children.first?.role, .button)
        XCTAssertEqual(element?.children.first?.children.first?.label, "Home")
    }

    // MARK: - JSON Serialization

    func testJSONSerialization() {
        let element = AccessibilityElement(
            role: .button,
            label: "OK",
            value: nil,
            frame: (x: 10, y: 20, width: 100, height: 40),
            children: []
        )

        let json = element.toJSON()

        XCTAssertTrue(json.contains("\"role\":\"button\""))
        XCTAssertTrue(json.contains("\"label\":\"OK\""))
        XCTAssertTrue(json.contains("\"value\":null"))
        XCTAssertTrue(json.contains("\"children\":[]"))
    }

    func testJSONEscapesSpecialCharacters() {
        let element = AccessibilityElement(
            role: .text,
            label: "Hello \"World\"",
            value: "line1\\line2",
            frame: (x: 0, y: 0, width: 0, height: 0),
            children: []
        )

        let json = element.toJSON()

        XCTAssertTrue(json.contains("\\\"World\\\""))
        XCTAssertTrue(json.contains("\\\\line2"))
    }
}
