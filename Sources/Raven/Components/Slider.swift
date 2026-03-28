// MARK: - Slider

/// A horizontal slider for selecting a value in a range.
///
/// Usage:
/// ```swift
/// let volume = StateVar<Float>(0.5)
/// Slider(value: volume.binding, range: 0...1, label: "Volume")
/// ```
public struct Slider: View {
    public typealias Body = Never

    let value: Binding<Float>
    let min: Float
    let max: Float
    let label: String

    public init(value: Binding<Float>, range: ClosedRange<Float> = 0...1, label: String = "") {
        self.value = value
        self.min = range.lowerBound
        self.max = range.upperBound
        self.label = label
    }

    public var body: Never { fatalError("Slider is a primitive") }
}
