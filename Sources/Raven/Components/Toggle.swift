// MARK: - Toggle

/// A switch-style toggle control.
///
/// Usage:
/// ```swift
/// let isEnabled = StateVar(false)
/// Toggle(isOn: isEnabled.binding, label: "Dark Mode")
/// ```
public struct Toggle: View {
    public typealias Body = Never

    let isOn: Binding<Bool>
    let label: String

    public init(isOn: Binding<Bool>, label: String = "") {
        self.isOn = isOn
        self.label = label
    }

    public var body: Never { fatalError("Toggle is a primitive") }
}
