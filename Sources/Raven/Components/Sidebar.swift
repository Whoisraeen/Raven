// MARK: - Sidebar

/// A two-pane layout with a fixed-width sidebar and a flexible detail area.
/// Standard desktop navigation pattern.
///
/// Usage:
/// ```swift
/// Sidebar(width: 240) {
///     // Sidebar content
///     VStack {
///         SidebarItem(label: "Home", isSelected: true) { selectTab("home") }
///         SidebarItem(label: "Settings", isSelected: false) { selectTab("settings") }
///     }
/// } detail: {
///     // Detail content
///     Text("Main content here")
/// }
/// ```
public struct Sidebar: View {
    public typealias Body = Never
    public var body: Never { fatalError("Sidebar is a primitive view") }

    public let sidebarWidth: Float
    internal let sidebarContent: [any View]
    internal let detailContent: [any View]

    public init(
        width: Float = 240,
        @ViewBuilder sidebar: () -> some View,
        @ViewBuilder detail: () -> some View
    ) {
        self.sidebarWidth = width
        self.sidebarContent = [sidebar()]
        self.detailContent = [detail()]
    }
}

// MARK: - SidebarItem

/// A clickable row within a Sidebar, with selection state and label.
///
/// Usage:
/// ```swift
/// SidebarItem(label: "Dashboard", isSelected: currentTab == "dashboard") {
///     currentTab = "dashboard"
/// }
/// ```
public struct SidebarItem: View {
    public typealias Body = Never
    public var body: Never { fatalError("SidebarItem is a primitive view") }

    public let label: String
    public let isSelected: Bool
    public let action: @Sendable () -> Void

    public init(label: String, isSelected: Bool = false, action: @escaping @Sendable () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }
}
