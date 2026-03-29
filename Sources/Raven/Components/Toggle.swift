// MARK: - Toggle

/// A boolean on/off switch that toggles state on click.
///
/// Usage:
/// ```swift
/// let isDarkMode = StateVar(false)
///
/// Toggle("Dark Mode", isOn: isDarkMode.binding)
///     .padding(12)
/// ```
public struct Toggle: View {
    public typealias Body = Never
    public var body: Never { fatalError("Toggle is a primitive view") }

    /// Label displayed next to the toggle switch.
    public let label: String

    /// Binding to the boolean state value.
    public let isOn: Binding<Bool>

    public init(_ label: String = "", isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }
}
