#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Animation Primitives

/// Defines the timing curve or physics for an animation.
public enum Animation: Sendable {
    case easeInOut(duration: Double)
    case easeIn(duration: Double)
    case easeOut(duration: Double)
    case linear(duration: Double)
    case spring(response: Double, dampingFraction: Double)
    
    public static let `default` = Animation.spring(response: 0.5, dampingFraction: 0.8)
    public static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

// MARK: - AnimatableProperty

/// Properties that can be smoothly transitioned.
public enum AnimatableProperty: Hashable, Sendable {
    case x
    case y
    case width
    case height
    case opacity
    case scale
    case rotation
    case color(String) // property name, e.g., "backgroundColor"
}

// MARK: - AnimationEngine

/// Manages active animations and interpolates values over time.
/// Thread-safe via RavenLock for the animation context; tick() must still be called from the main thread.
public class AnimationEngine: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = AnimationEngine()

    private var activeAnimations: [AnimationInstance] = []
    private let lock = RavenLock()

    private init() {}
    
    /// The current animation context (set by withAnimation).
    /// Protected by lock for safe access from background closures.
    private var _currentAnimation: Animation? = nil
    public var currentAnimation: Animation? {
        get { lock.withLock { _currentAnimation } }
        set { lock.withLock { _currentAnimation = newValue } }
    }
    
    /// Update all active animations. Called every frame.
    public func tick(deltaTime: Double) {
        var remaining: [AnimationInstance] = []

        for var animation in activeAnimations {
            animation.elapsed += deltaTime
            let isFinished = animation.update()

            if !isFinished {
                remaining.append(animation)
            }
        }

        activeAnimations = remaining

        // Signal that a re-render is needed if any animation updated
        if !activeAnimations.isEmpty {
            StateTracker.shared.markDirty()
        }

        // Also tick callback-based animations (scroll, etc.)
        tickCallbackAnimations(deltaTime: deltaTime)
    }
    
    func addAnimation(_ instance: AnimationInstance) {
        activeAnimations.append(instance)
    }

    // MARK: - Callback-based Animations (used by scroll, etc.)

    private var callbackAnimations: [CallbackAnimationInstance] = []

    /// Animate a value over time with a callback. Used for scroll offsets and other
    /// non-property animations.
    public func animate(duration: Double = 0.3, from start: Float, to end: Float, update: @escaping (Float) -> Void) {
        let instance = CallbackAnimationInstance(duration: duration, start: start, end: end, update: update)
        callbackAnimations.append(instance)
    }

    /// Tick callback-based animations. Called from the main tick method.
    private func tickCallbackAnimations(deltaTime: Double) {
        guard !callbackAnimations.isEmpty else { return }

        var i = 0
        while i < callbackAnimations.count {
            let anim = callbackAnimations[i]
            anim.elapsed += deltaTime

            let progress = min(1.0, Float(anim.elapsed / anim.duration))
            let t = easeOutQuint(progress)
            let value = anim.start + (anim.end - anim.start) * t

            anim.update(value)

            if progress >= 1.0 {
                callbackAnimations.remove(at: i)
            } else {
                i += 1
            }
        }

        if !callbackAnimations.isEmpty {
            StateTracker.shared.markDirty()
        }
    }

    private func easeOutQuint(_ x: Float) -> Float {
        return 1 - powf(1 - x, 5)
    }
}

// MARK: - AnimationInstance (Internal)

class AnimationInstance {
    weak var node: LayoutNode?
    let property: AnimatableProperty
    let startValue: Float
    let targetValue: Float
    let animation: Animation
    var elapsed: Double = 0

    init(node: LayoutNode, property: AnimatableProperty, startValue: Float, targetValue: Float, animation: Animation) {
        self.node = node
        self.property = property
        self.startValue = startValue
        self.targetValue = targetValue
        self.animation = animation
    }

    /// Updates the node's property. Returns true if finished.
    func update() -> Bool {
        // If the node was deallocated, consider the animation finished
        guard node != nil else { return true }
        switch animation {
        case .linear(let duration):
            guard duration > 0 else { apply(value: targetValue); return true }
            let t = Float(min(elapsed / duration, 1.0))
            apply(value: startValue + (targetValue - startValue) * t)
            return elapsed >= duration

        case .easeInOut(let duration):
            guard duration > 0 else { apply(value: targetValue); return true }
            let t = min(elapsed / duration, 1.0)
            let smoothT = Float(t * t * (3 - 2 * t)) // Basic Hermite
            apply(value: startValue + (targetValue - startValue) * smoothT)
            return elapsed >= duration

        case .easeIn(let duration):
            guard duration > 0 else { apply(value: targetValue); return true }
            let t = Float(min(elapsed / duration, 1.0))
            let curved = t * t // Quadratic ease-in
            apply(value: startValue + (targetValue - startValue) * curved)
            return elapsed >= duration

        case .easeOut(let duration):
            guard duration > 0 else { apply(value: targetValue); return true }
            let t = Float(min(elapsed / duration, 1.0))
            let curved = 1 - (1 - t) * (1 - t) // Quadratic ease-out
            apply(value: startValue + (targetValue - startValue) * curved)
            return elapsed >= duration

        case .spring(let response, let dampingFraction):
            // Clamp parameters to avoid NaN/overflow
            let safeResponse = max(response, 0.01)
            let safeDamping = min(max(dampingFraction, 0.0), 1.0)

            let stiffness = pow(2.0 * .pi / safeResponse, 2.0)
            let damping = 4.0 * .pi * safeDamping / safeResponse

            let t = elapsed
            let x0 = Double(targetValue - startValue)

            let value: Double
            if safeDamping < 1.0 {
                // Underdamped
                let wd = sqrt(stiffness) * sqrt(1.0 - safeDamping * safeDamping)
                let a = x0
                let b = (damping / 2.0 * x0) / wd
                value = exp(-damping / 2.0 * t) * (a * cos(wd * t) + b * sin(wd * t))
            } else {
                // Critically damped
                value = x0 * (1.0 + (damping / 2.0) * t) * exp(-damping / 2.0 * t)
            }

            let current = Float(Double(targetValue) - value)
            apply(value: current.isNaN ? targetValue : current)

            let isClose = abs(current - targetValue) < 0.01
            return isClose && elapsed > safeResponse * 2.0

        }
    }
    
    private func apply(value: Float) {
        guard let node = node else { return }
        switch property {
        case .x: node.x = value
        case .y: node.y = value
        case .width: node.width = value
        case .height: node.height = value
        case .opacity: node.opacity = value
        case .scale: node.scale = value
        case .rotation: node.rotation = value
        case .color(_): break // Needs color interpolation logic
        }
    }
}

// MARK: - CallbackAnimationInstance

private class CallbackAnimationInstance {
    let duration: Double
    let start: Float
    let end: Float
    var elapsed: Double = 0
    let update: (Float) -> Void

    init(duration: Double, start: Float, end: Float, update: @escaping (Float) -> Void) {
        self.duration = duration
        self.start = start
        self.end = end
        self.update = update
    }
}

/// Perform a state update with an animation.
public func withAnimation(_ animation: Animation = .default, _ action: () -> Void) {
    AnimationEngine.shared.currentAnimation = animation
    action()
    AnimationEngine.shared.currentAnimation = nil
}
