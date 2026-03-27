// MARK: - TextField

/// A text input field with cursor and keyboard support.
///
/// Usage:
/// ```swift
/// let name = StateVar("")
///
/// TextField("Enter name...", text: name.binding)
///     .padding(12)
///     .background(.surface)
/// ```
public struct TextField: View {
    public typealias Body = Never
    public var body: Never { fatalError("TextField is a primitive view") }

    /// Placeholder text (shown when the field is empty)
    public let placeholder: String

    /// Binding to the text value
    public let text: Binding<String>

    /// Visual properties
    public internal(set) var textColor: Color? = nil
    public internal(set) var placeholderColor: Color? = nil
    public internal(set) var backgroundColor: Color? = nil
    public internal(set) var borderColor: Color? = nil

    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }
}
