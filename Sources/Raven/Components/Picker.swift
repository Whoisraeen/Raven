// MARK: - Picker

/// A dropdown selector for choosing from a list of options.
///
/// Usage:
/// ```swift
/// let selected = StateVar(0)
/// Picker(selection: selected.binding, options: ["Small", "Medium", "Large"])
/// ```
public struct Picker: View {
    public typealias Body = Never

    let selection: Binding<Int>
    let options: [String]
    let label: String

    public init(selection: Binding<Int>, options: [String], label: String = "") {
        self.selection = selection
        self.options = options
        self.label = label
    }

    public var body: Never { fatalError("Picker is a primitive") }
}
