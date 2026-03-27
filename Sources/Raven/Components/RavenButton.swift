// MARK: - Button

/// A clickable button that performs an action when pressed.
/// Currently renders as a colored rectangle with a text label.
public struct Button: View {
    public typealias Body = Never
    public var body: Never { fatalError("Button is a primitive view") }

    public let label: String
    public let action: @Sendable () -> Void
    public internal(set) var backgroundColor: Color? = nil
    public internal(set) var foregroundColor: Color? = nil

    public init(_ label: String, action: @escaping @Sendable () -> Void) {
        self.label = label
        self.action = action
    }
}
