// MARK: - NavigationStack

/// A container that manages a stack-based navigation flow.
/// Push and pop views using the `NavigationPath` state.
///
/// Usage:
/// ```swift
/// let path = NavigationPath()
///
/// NavigationStack(path: path) {
///     VStack {
///         Text("Home")
///         Button("Go to Detail") {
///             path.push("detail")
///         }
///     }
/// }
/// .navigationDestination(for: "detail") {
///     VStack {
///         Text("Detail View")
///         Button("Back") { path.pop() }
///     }
/// }
/// ```
public struct NavigationStack: View {
    public typealias Body = Never
    public var body: Never { fatalError("NavigationStack is a primitive view") }

    public let path: NavigationPath
    internal let rootContent: [any View]
    internal var destinations: [String: () -> any View]

    public init(
        path: NavigationPath,
        @ViewBuilder content: () -> some View
    ) {
        self.path = path
        self.rootContent = [content()]
        self.destinations = [:]
    }

    /// Register a destination view for a given route identifier.
    public func navigationDestination(for route: String, @ViewBuilder destination: @escaping () -> some View) -> NavigationStack {
        var copy = self
        copy.destinations[route] = destination
        return copy
    }
}

// MARK: - NavigationPath

/// Observable navigation state that drives a NavigationStack.
/// Maintains a stack of route identifiers.
public class NavigationPath: @unchecked Sendable {
    private var _stack: [String] = []

    public init() {}

    /// The current route stack.
    public var stack: [String] { _stack }

    /// The current (topmost) route, or nil if at root.
    public var current: String? { _stack.last }

    /// Whether the stack is at the root level.
    public var isAtRoot: Bool { _stack.isEmpty }

    /// Push a new route onto the stack.
    public func push(_ route: String) {
        _stack.append(route)
        StateTracker.shared.markDirty()
    }

    /// Pop the top route off the stack. No-op if already at root.
    public func pop() {
        guard !_stack.isEmpty else { return }
        _stack.removeLast()
        StateTracker.shared.markDirty()
    }

    /// Pop all routes, returning to root.
    public func popToRoot() {
        guard !_stack.isEmpty else { return }
        _stack.removeAll()
        StateTracker.shared.markDirty()
    }

    /// Replace the entire stack with a single route.
    public func replace(with route: String) {
        _stack = [route]
        StateTracker.shared.markDirty()
    }
}
