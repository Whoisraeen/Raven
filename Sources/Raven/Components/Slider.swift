// MARK: - Slider

/// A horizontal draggable control for selecting a Float value within a range.
///
/// Usage:
/// ```swift
/// let volume = StateVar<Float>(0.5)
///
/// Slider(value: volume.binding, in: 0...1)
///     .padding(12)
///
/// // With step increments:
/// Slider(value: brightness.binding, in: 0...100, step: 10)
/// ```
public struct Slider: View {
    public typealias Body = Never
    public var body: Never { fatalError("Slider is a primitive view") }

    /// Binding to the current value.
    public let value: Binding<Float>

    /// The valid range of values.
    public let range: ClosedRange<Float>

    /// Optional step increment. If set, the slider snaps to multiples of this value.
    public let step: Float?

    public init(value: Binding<Float>, in range: ClosedRange<Float> = 0...1, step: Float? = nil) {
        self.value = value
        self.range = range
        self.step = step
    }
}
