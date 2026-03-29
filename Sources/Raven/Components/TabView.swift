// MARK: - TabView

/// A tab-based navigation container. Each tab has a label and a content view.
///
/// Usage:
/// ```swift
/// let selectedTab = StateVar(0)
///
/// TabView(selection: selectedTab.binding) {
///     Text("Home Content")
///         .tabItem("Home", index: 0)
///     Text("Settings Content")
///         .tabItem("Settings", index: 1)
/// }
/// ```
public struct TabView: View {
    public typealias Body = Never
    public var body: Never { fatalError("TabView is a primitive view") }

    /// Binding to the currently selected tab index.
    public let selection: Binding<Int>

    /// The tab items (label + content pairs).
    public let tabs: [TabItem]

    public init(selection: Binding<Int>, @TabBuilder tabs: () -> [TabItem]) {
        self.selection = selection
        self.tabs = tabs()
    }
}

/// A single tab item with a label and associated view content.
public struct TabItem: @unchecked Sendable {
    public let label: String
    public let index: Int
    public let content: [any View]

    public init(label: String, index: Int, content: [any View]) {
        self.label = label
        self.index = index
        self.content = content
    }
}

/// A result builder for constructing tab items.
@resultBuilder
public struct TabBuilder {
    public static func buildBlock(_ components: TabItem...) -> [TabItem] {
        components
    }
}

/// Modifier to create tab items from views.
extension View {
    /// Wrap this view as a tab item with a label and index.
    public func tabItem(_ label: String, index: Int) -> TabItem {
        TabItem(label: label, index: index, content: [self])
    }
}
