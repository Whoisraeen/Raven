// MARK: - NavigationView

/// A push/pop navigation container with a title bar.
/// Content is displayed in a stack-based navigation model.
///
/// Usage:
/// ```swift
/// NavigationView(title: "My App") {
///     VStack {
///         Text("Welcome!")
///         Button("Go to Details") {
///             // Push a new view onto the navigation stack
///         }
///     }
/// }
/// ```
public struct NavigationView: View {
    public typealias Body = Never
    public var body: Never { fatalError("NavigationView is a primitive view") }

    /// The title displayed in the navigation bar.
    public let title: String

    /// The root content of the navigation view.
    public let content: [any View]

    public init(title: String = "", @ViewBuilder content: () -> any View) {
        self.title = title
        self.content = [content()]
    }
}

// MARK: - Divider

// Note: Divider is defined in Components/Divider.swift
