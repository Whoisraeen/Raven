// MARK: - List

/// A scrollable list of items with optional dividers between rows.
/// Combines ScrollView + ForEach + VStack with list-specific styling.
///
/// Usage:
/// ```swift
/// List(items) { item in
///     Text(item.name)
/// }
/// .frame(height: 400)
/// ```
///
/// Or with a range:
/// ```swift
/// List(0..<50) { i in
///     Text("Row \(i)")
/// }
/// ```
public struct List<Data: RandomAccessCollection, Content: View>: View where Data.Index: Hashable {
    public typealias Body = Never
    public var body: Never { fatalError("List is a primitive view") }

    let data: Data
    let content: (Data.Element) -> Content
    let showDividers: Bool

    public init(_ data: Data, showDividers: Bool = true, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
        self.showDividers = showDividers
    }
}

/// Integer range convenience
extension List where Data == Range<Int> {
    public init(_ range: Range<Int>, showDividers: Bool = true, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = range
        self.content = content
        self.showDividers = showDividers
    }
}

// MARK: - List Resolution

protocol AnyListView {
    func resolveList(path: String) -> LayoutNode
}

extension List: AnyListView {
    func resolveList(path: String) -> LayoutNode {
        let theme = Theme.current

        // Outer scroll container
        let scrollNode = LayoutNode()
        scrollNode.isScrollView = true
        scrollNode.scrollAxis = .vertical
        scrollNode.scrollOffset = 0
        scrollNode.id = "\(path).ls"

        // Inner VStack content
        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.spacing = 0
        contentNode.id = "\(path).lc"

        var children: [LayoutNode] = []
        for (index, element) in data.enumerated() {
            if showDividers && index > 0 {
                let divider = LayoutNode()
                divider.fixedHeight = 1
                divider.backgroundColor = theme.colors.divider
                divider.id = "\(path).ld\(index)"
                children.append(divider)
            }

            let childView = content(element)
            let childNode = ViewResolver.resolve(childView, path: "\(path).li\(index)")
            // Add default row padding if the child doesn't already have it
            if childNode.padding.top == 0 && childNode.padding.bottom == 0 {
                childNode.padding = EdgeInsets(
                    top: 8,
                    leading: childNode.padding.leading > 0 ? childNode.padding.leading : 12,
                    bottom: 8,
                    trailing: childNode.padding.trailing > 0 ? childNode.padding.trailing : 12
                )
            }
            children.append(childNode)
        }

        contentNode.children = children
        scrollNode.children = [contentNode]
        scrollNode.accessibilityRole = .scrollArea
        return scrollNode
    }
}
