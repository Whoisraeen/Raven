import XCTest
@testable import Raven

final class AnimationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flush any lingering animations
        AnimationEngine.shared.tick(deltaTime: 100)
    }

    // MARK: - Callback Animations

    func testAnimationCallsUpdate() {
        var lastValue: Float = -1

        AnimationEngine.shared.animate(
            duration: 1.0,
            from: 0,
            to: 100
        ) { value in
            lastValue = value
        }

        // Tick halfway
        AnimationEngine.shared.tick(deltaTime: 0.5)
        XCTAssertGreaterThan(lastValue, 0)
        XCTAssertLessThan(lastValue, 100)

        // Tick to completion
        AnimationEngine.shared.tick(deltaTime: 0.6)
        XCTAssertEqual(lastValue, 100, accuracy: 0.01)
    }

    func testAnimationPrunesFinished() {
        var completed = false

        AnimationEngine.shared.animate(
            duration: 0.1,
            from: 0,
            to: 1
        ) { value in
            if value >= 1 { completed = true }
        }

        // Complete the animation
        AnimationEngine.shared.tick(deltaTime: 0.2)
        XCTAssertTrue(completed)

        // After another tick, the finished animation should be pruned (no crash)
        AnimationEngine.shared.tick(deltaTime: 0.1)
    }

    func testZeroDurationAnimation() {
        var lastValue: Float = -1

        AnimationEngine.shared.animate(
            duration: 0.001, // Near-zero
            from: 0,
            to: 50
        ) { value in
            lastValue = value
        }

        AnimationEngine.shared.tick(deltaTime: 0.01)
        XCTAssertEqual(lastValue, 50, accuracy: 0.5)
    }

    // MARK: - Property Animations

    func testLinearPropertyAnimation() {
        let node = LayoutNode()
        node.x = 0

        let instance = AnimationInstance(
            node: node,
            property: .x,
            startValue: 0,
            targetValue: 100,
            animation: .linear(duration: 1.0)
        )

        // Halfway
        instance.elapsed = 0.5
        let _ = instance.update()
        XCTAssertEqual(node.x, 50, accuracy: 0.01)

        // Complete
        instance.elapsed = 1.0
        let finished = instance.update()
        XCTAssertEqual(node.x, 100, accuracy: 0.01)
        XCTAssertTrue(finished)
    }

    func testEaseInOutPropertyAnimation() {
        let node = LayoutNode()
        node.opacity = 0

        let instance = AnimationInstance(
            node: node,
            property: .opacity,
            startValue: 0,
            targetValue: 1,
            animation: .easeInOut(duration: 1.0)
        )

        // At t=0.5, Hermite smoothstep = 0.5
        instance.elapsed = 0.5
        let _ = instance.update()
        XCTAssertEqual(node.opacity, 0.5, accuracy: 0.01)

        // At t=1.0, should be 1.0
        instance.elapsed = 1.0
        let finished = instance.update()
        XCTAssertEqual(node.opacity, 1.0, accuracy: 0.01)
        XCTAssertTrue(finished)
    }

    func testEaseInStartsSlow() {
        let node = LayoutNode()

        let instance = AnimationInstance(
            node: node,
            property: .x,
            startValue: 0,
            targetValue: 100,
            animation: .easeIn(duration: 1.0)
        )

        // At t=0.25, easeIn (quadratic) = 0.25^2 = 0.0625 -> x = 6.25
        instance.elapsed = 0.25
        let _ = instance.update()
        XCTAssertLessThan(node.x, 25) // Below linear
    }

    func testEaseOutStartsFast() {
        let node = LayoutNode()

        let instance = AnimationInstance(
            node: node,
            property: .x,
            startValue: 0,
            targetValue: 100,
            animation: .easeOut(duration: 1.0)
        )

        // At t=0.25, easeOut = 1-(1-0.25)^2 = 1-0.5625 = 0.4375 -> x = 43.75
        instance.elapsed = 0.25
        let _ = instance.update()
        XCTAssertGreaterThan(node.x, 25) // Above linear
    }

    func testDeallocatedNodeFinishesAnimation() {
        var node: LayoutNode? = LayoutNode()

        let instance = AnimationInstance(
            node: node!,
            property: .x,
            startValue: 0,
            targetValue: 100,
            animation: .linear(duration: 1.0)
        )

        // Deallocate the node
        node = nil

        // Should return true (finished) since node is gone
        instance.elapsed = 0.5
        let finished = instance.update()
        XCTAssertTrue(finished)
    }
}
