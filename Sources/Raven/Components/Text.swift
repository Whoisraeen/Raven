// MARK: - Text

/// A view that displays a string of text.
/// Currently renders as a placeholder colored rectangle
/// until SDF font rendering is implemented.
public struct Text: View {
    public typealias Body = Never
    public var body: Never { fatalError("Text is a primitive view") }

    public let content: String
    public internal(set) var color: Color? = nil

    public init(_ content: String) {
        self.content = content
    }
}
