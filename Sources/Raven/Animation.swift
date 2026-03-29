import Foundation

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
public class AnimationEngine: @unchecked Sendable {
    public static let shared = AnimationEngine()
    
    private var activeAnimations: [AnimationInstance] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// The current animation context (set by withAnimation)
    public internal(set) var currentAnimation: Animation? = nil
    
    /// Update all active animations. Called every frame.
    public func tick(deltaTime: Double) {
        lock.lock()
        defer { lock.unlock() }
        
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
    }
    
    func addAnimation(_ instance: AnimationInstance) {
        lock.lock()
        defer { lock.unlock() }
        activeAnimations.append(instance)
    }
}

// MARK: - AnimationInstance (Internal)

struct AnimationInstance {
    let node: LayoutNode
    let property: AnimatableProperty
    let startValue: Float
    let targetValue: Float
    let animation: Animation
    var elapsed: Double = 0
    
    /// Updates the node's property. Returns true if finished.
    func update() -> Bool {
        switch animation {
        case .linear(let duration):
            let t = Float(min(elapsed / duration, 1.0))
            apply(value: startValue + (targetValue - startValue) * t)
            return elapsed >= duration
            
        case .easeInOut(let duration):
            let t = min(elapsed / duration, 1.0)
            let smoothT = Float(t * t * (3 - 2 * t)) // Basic Hermite
            apply(value: startValue + (targetValue - startValue) * smoothT)
            return elapsed >= duration
            
        case .spring(let response, let dampingFraction):
            // Simple Damped Spring Simulation (approximated)
            // For a production engine, we'd use a real integrator, 
            // but this analytic solution works for simple UI.
            let stiffness = pow(2.0 * .pi / response, 2.0)
            let damping = 4.0 * .pi * dampingFraction / response
            
            let t = elapsed
            let x0 = Double(targetValue - startValue)
            
            // Critical damping check
            let value: Double
            if dampingFraction < 1.0 {
                // Underdamped
                let wd = sqrt(stiffness) * sqrt(1.0 - dampingFraction * dampingFraction)
                let a = x0
                let b = (damping / 2.0 * x0) / wd
                value = exp(-damping / 2.0 * t) * (a * cos(wd * t) + b * sin(wd * t))
            } else {
                // Critically damped or Overdamped
                let value1 = x0 * (1.0 + (damping / 2.0) * t) * exp(-damping / 2.0 * t)
                value = value1
            }
            
            let current = Float(Double(targetValue) - value)
            apply(value: current)
            
            // Finish when close enough and enough time has passed
            let isClose = abs(current - targetValue) < 0.01
            return isClose && elapsed > response * 2.0
            
        default:
            apply(value: targetValue)
            return true
        }
    }
    
    private func apply(value: Float) {
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

/// Perform a state update with an animation.
public func withAnimation(_ animation: Animation = .default, _ action: () -> Void) {
    AnimationEngine.shared.currentAnimation = animation
    action()
    AnimationEngine.shared.currentAnimation = nil
}
