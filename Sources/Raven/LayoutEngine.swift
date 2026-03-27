// MARK: - LayoutEngine

/// Resolves a LayoutNode tree by assigning positions and sizes.
/// Uses a two-pass approach:
/// 1. Measure (bottom-up) — calculate intrinsic sizes
/// 2. Layout (top-down) — assign positions based on parent constraints
public enum LayoutEngine {

    /// Resolve the full layout tree within the given viewport.
    public static func resolve(root: LayoutNode, viewportWidth: Float, viewportHeight: Float) {
        // The root node fills the entire viewport
        root.x = 0
        root.y = 0
        root.width = root.fixedWidth ?? viewportWidth
        root.height = root.fixedHeight ?? viewportHeight
        layoutChildren(of: root)
    }

    /// Recursively layout the children of a node.
    private static func layoutChildren(of node: LayoutNode) {
        let children = node.children
        if children.isEmpty { return }

        // Available content area (inside padding)
        let contentX = node.x + node.padding.leading
        let contentY = node.y + node.padding.top
        let contentWidth = node.width - node.padding.leading - node.padding.trailing
        let contentHeight = node.height - node.padding.top - node.padding.bottom

        switch node.stackAxis {
        case .vertical:
            layoutVerticalStack(
                children: children,
                contentX: contentX, contentY: contentY,
                contentWidth: contentWidth, contentHeight: contentHeight,
                spacing: node.spacing,
                alignment: node.horizontalAlignment
            )
        case .horizontal:
            layoutHorizontalStack(
                children: children,
                contentX: contentX, contentY: contentY,
                contentWidth: contentWidth, contentHeight: contentHeight,
                spacing: node.spacing,
                alignment: node.verticalAlignment
            )
        case .zStack:
            layoutZStack(
                children: children,
                contentX: contentX, contentY: contentY,
                contentWidth: contentWidth, contentHeight: contentHeight
            )
        case nil:
            // No stack axis — children fill the content area
            for child in children {
                child.x = contentX
                child.y = contentY
                child.width = child.fixedWidth ?? contentWidth
                child.height = child.fixedHeight ?? contentHeight
                layoutChildren(of: child)
            }
        }
    }

    // MARK: - Vertical Stack

    private static func layoutVerticalStack(
        children: [LayoutNode],
        contentX: Float, contentY: Float,
        contentWidth: Float, contentHeight: Float,
        spacing: Float,
        alignment: HorizontalAlignment
    ) {
        // Calculate total spacing
        let totalSpacing = children.count > 1 ? Float(children.count - 1) * spacing : 0

        // Find flexible children and total fixed height
        let flexibleChildren = children.filter { $0.isFlexible }
        let fixedChildren = children.filter { !$0.isFlexible }
        let fixedHeight = fixedChildren.reduce(Float(0)) { $0 + $1.intrinsicHeight }
        let remainingHeight = max(0, contentHeight - fixedHeight - totalSpacing)
        let flexibleShare = flexibleChildren.isEmpty ? Float(0) : remainingHeight / Float(flexibleChildren.count)

        // Layout pass: assign positions top-to-bottom
        var currentY = contentY

        for child in children {
            let childHeight: Float
            if child.isFlexible {
                childHeight = flexibleShare
            } else {
                childHeight = child.fixedHeight ?? child.intrinsicHeight
            }

            let childWidth = child.fixedWidth ?? contentWidth

            // Horizontal alignment within the stack
            let childX: Float
            switch alignment {
            case .leading:
                childX = contentX
            case .center:
                childX = contentX + (contentWidth - childWidth) / 2
            case .trailing:
                childX = contentX + contentWidth - childWidth
            }

            child.x = childX
            child.y = currentY
            child.width = childWidth
            child.height = childHeight

            layoutChildren(of: child)

            currentY += childHeight + spacing
        }
    }

    // MARK: - Horizontal Stack

    private static func layoutHorizontalStack(
        children: [LayoutNode],
        contentX: Float, contentY: Float,
        contentWidth: Float, contentHeight: Float,
        spacing: Float,
        alignment: VerticalAlignment
    ) {
        let totalSpacing = children.count > 1 ? Float(children.count - 1) * spacing : 0

        let flexibleChildren = children.filter { $0.isFlexible }
        let fixedChildren = children.filter { !$0.isFlexible }
        let fixedWidth = fixedChildren.reduce(Float(0)) { $0 + $1.intrinsicWidth }
        let remainingWidth = max(0, contentWidth - fixedWidth - totalSpacing)
        let flexibleShare = flexibleChildren.isEmpty ? Float(0) : remainingWidth / Float(flexibleChildren.count)

        var currentX = contentX

        for child in children {
            let childWidth: Float
            if child.isFlexible {
                childWidth = flexibleShare
            } else {
                childWidth = child.fixedWidth ?? child.intrinsicWidth
            }

            let childHeight = child.fixedHeight ?? contentHeight

            let childY: Float
            switch alignment {
            case .top:
                childY = contentY
            case .center:
                childY = contentY + (contentHeight - childHeight) / 2
            case .bottom:
                childY = contentY + contentHeight - childHeight
            }

            child.x = currentX
            child.y = childY
            child.width = childWidth
            child.height = childHeight

            layoutChildren(of: child)

            currentX += childWidth + spacing
        }
    }

    // MARK: - Z Stack

    private static func layoutZStack(
        children: [LayoutNode],
        contentX: Float, contentY: Float,
        contentWidth: Float, contentHeight: Float
    ) {
        for child in children {
            let childWidth = child.fixedWidth ?? contentWidth
            let childHeight = child.fixedHeight ?? contentHeight

            // Center each child
            child.x = contentX + (contentWidth - childWidth) / 2
            child.y = contentY + (contentHeight - childHeight) / 2
            child.width = childWidth
            child.height = childHeight

            layoutChildren(of: child)
        }
    }
}
