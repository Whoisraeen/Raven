import XCTest
@testable import Raven

final class LayoutEngineTests: XCTestCase {

    // MARK: - Basic Layout

    func testRootFillsViewport() {
        let root = LayoutNode()
        root.stackAxis = .vertical

        LayoutEngine.resolve(root: root, viewportWidth: 800, viewportHeight: 600)

        XCTAssertEqual(root.x, 0)
        XCTAssertEqual(root.y, 0)
        XCTAssertEqual(root.width, 800)
        XCTAssertEqual(root.height, 600)
    }

    func testVerticalStackDistribution() {
        let root = LayoutNode()
        root.stackAxis = .vertical
        root.spacing = 10

        let child1 = LayoutNode()
        child1.fixedHeight = 100

        let child2 = LayoutNode()
        child2.fixedHeight = 50

        root.children = [child1, child2]

        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 300)

        XCTAssertEqual(child1.y, 0)
        XCTAssertEqual(child1.height, 100)
        XCTAssertEqual(child2.y, 110) // 100 + 10 spacing
        XCTAssertEqual(child2.height, 50)
    }

    func testHorizontalStackDistribution() {
        let root = LayoutNode()
        root.stackAxis = .horizontal
        root.spacing = 5

        let child1 = LayoutNode()
        child1.fixedWidth = 100

        let child2 = LayoutNode()
        child2.fixedWidth = 200

        root.children = [child1, child2]

        LayoutEngine.resolve(root: root, viewportWidth: 800, viewportHeight: 600)

        XCTAssertEqual(child1.x, 0)
        XCTAssertEqual(child1.width, 100)
        XCTAssertEqual(child2.x, 105) // 100 + 5 spacing
        XCTAssertEqual(child2.width, 200)
    }

    func testFlexibleChildrenShareSpace() {
        let root = LayoutNode()
        root.stackAxis = .horizontal
        root.spacing = 0

        let fixed = LayoutNode()
        fixed.fixedWidth = 200

        let flex1 = LayoutNode()
        flex1.isFlexible = true

        let flex2 = LayoutNode()
        flex2.isFlexible = true

        root.children = [fixed, flex1, flex2]

        LayoutEngine.resolve(root: root, viewportWidth: 600, viewportHeight: 400)

        XCTAssertEqual(fixed.width, 200)
        // Remaining 400 split evenly between flex1 and flex2
        XCTAssertEqual(flex1.width, 200)
        XCTAssertEqual(flex2.width, 200)
    }

    func testVerticalFlexibleChildren() {
        let root = LayoutNode()
        root.stackAxis = .vertical
        root.spacing = 0

        let fixed = LayoutNode()
        fixed.fixedHeight = 100

        let spacer = LayoutNode()
        spacer.isFlexible = true

        root.children = [fixed, spacer]

        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 500)

        XCTAssertEqual(fixed.height, 100)
        XCTAssertEqual(spacer.height, 400) // 500 - 100
    }

    func testPaddingApplied() {
        let root = LayoutNode()
        root.stackAxis = .vertical
        root.padding = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)

        let child = LayoutNode()
        child.fixedHeight = 50

        root.children = [child]

        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 300)

        XCTAssertEqual(child.x, 20)     // leading padding
        XCTAssertEqual(child.y, 10)     // top padding
        XCTAssertEqual(child.width, 360) // 400 - 20 - 20
    }

    func testZStackChildrenOverlap() {
        let root = LayoutNode()
        root.stackAxis = .zStack

        let bg = LayoutNode()
        bg.fixedWidth = 200
        bg.fixedHeight = 200

        let fg = LayoutNode()
        fg.fixedWidth = 100
        fg.fixedHeight = 100

        root.children = [bg, fg]

        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 400)

        // Both should be centered
        XCTAssertEqual(bg.x, 100)  // (400-200)/2
        XCTAssertEqual(bg.y, 100)
        XCTAssertEqual(fg.x, 150)  // (400-100)/2
        XCTAssertEqual(fg.y, 150)
    }

    // MARK: - Incremental Layout

    func testCleanSubtreeSkipped() {
        let root = LayoutNode()
        root.stackAxis = .vertical

        let child = LayoutNode()
        child.fixedHeight = 100

        root.children = [child]

        // First resolve establishes sizes
        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 300)

        // Now mark everything clean and set an intentionally wrong position
        root.markLayoutClean()
        child.x = 99

        // Second resolve with same viewport — tree is clean, should skip
        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 300)

        // Child position should NOT be corrected since subtree was clean
        XCTAssertEqual(child.x, 99)
    }

    func testDirtySubtreeRelaidOut() {
        let root = LayoutNode()
        root.stackAxis = .vertical
        root.needsLayout = true

        let child = LayoutNode()
        child.fixedHeight = 100
        child.needsLayout = true
        child.x = 99

        root.children = [child]

        LayoutEngine.resolve(root: root, viewportWidth: 400, viewportHeight: 300)

        XCTAssertEqual(child.x, 0) // Should be corrected
    }

    // MARK: - Intrinsic Size

    func testFixedWidthIntrinsic() {
        let node = LayoutNode()
        node.fixedWidth = 150

        XCTAssertEqual(node.cachedIntrinsicWidth, 150)
    }

    func testHorizontalStackIntrinsicWidth() {
        let parent = LayoutNode()
        parent.stackAxis = .horizontal
        parent.spacing = 5

        let c1 = LayoutNode()
        c1.fixedWidth = 100

        let c2 = LayoutNode()
        c2.fixedWidth = 200

        parent.children = [c1, c2]

        // Intrinsic width = 100 + 200 + 5 spacing = 305
        XCTAssertEqual(parent.cachedIntrinsicWidth, 305)
    }
}
