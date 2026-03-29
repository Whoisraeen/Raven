// MARK: - LayoutEngine

/// Resolves a LayoutNode tree by assigning positions and sizes.
/// Uses a two-pass approach:
/// 1. Measure (bottom-up) — calculate intrinsic sizes (with caching)
/// 2. Layout (top-down) — assign positions based on parent constraints
///
/// Optimizations:
/// - Intrinsic size caching: each node caches its measured size and only recalculates when dirty
/// - Subtree pruning: clean subtrees skip relayout entirely
public enum LayoutEngine {

    /// Resolve the full layout tree within the given viewport.
    /// Supports incremental layout: clean subtrees are skipped when the
    /// viewport dimensions haven't changed, reducing per-frame work.
    public static func resolve(root: LayoutNode, viewportWidth: Float, viewportHeight: Float) {
        // Detect viewport size change — forces full relayout
        let rootWidth = root.fixedWidth ?? viewportWidth
        let rootHeight = root.fixedHeight ?? viewportHeight
        let viewportChanged = root.width != rootWidth || root.height != rootHeight

        // The root node fills the entire viewport
        root.x = 0
        root.y = 0
        root.width = rootWidth
        root.height = rootHeight

        if viewportChanged {
            root.needsLayout = true
        }

        layoutChildren(of: root)

        // Mark the entire tree as clean after layout
        root.markLayoutClean()
    }

    /// Recursively layout the children of a node.
    /// Skips subtrees where no node is marked dirty (needsLayout == false).
    private static func layoutChildren(of node: LayoutNode) {
        let children = node.children
        if children.isEmpty { return }

        // If this node doesn't need layout and none of its descendants do either,
        // skip the entire subtree.
        let subtreeNeedsLayout = node.needsLayout || children.contains { $0.needsLayout }
        guard subtreeNeedsLayout else { return }

        // Available content area (inside padding)
        var contentX = node.x + node.padding.leading
        var contentY = node.y + node.padding.top
        let contentWidth = node.width - node.padding.leading - node.padding.trailing
        let contentHeight = node.height - node.padding.top - node.padding.bottom

        // Apply scroll offset to content origin
        if node.isScrollView {
            let offset = node.scrollOffset
            switch node.scrollAxis {
            case .vertical, nil:
                contentY -= offset
            case .horizontal:
                contentX -= offset
            }
        }

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
            if node.flexWrap {
                layoutFlexWrap(
                    children: children,
                    contentX: contentX, contentY: contentY,
                    contentWidth: contentWidth, contentHeight: contentHeight,
                    spacing: node.spacing,
                    lineSpacing: node.lineSpacing
                )
            } else if node.alignToBaseline {
                layoutHorizontalStackBaseline(
                    children: children,
                    contentX: contentX, contentY: contentY,
                    contentWidth: contentWidth, contentHeight: contentHeight,
                    spacing: node.spacing
                )
            } else {
                layoutHorizontalStack(
                    children: children,
                    contentX: contentX, contentY: contentY,
                    contentWidth: contentWidth, contentHeight: contentHeight,
                    spacing: node.spacing,
                    alignment: node.verticalAlignment
                )
            }
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
        let totalSpacing = children.count > 1 ? Float(children.count - 1) * spacing : 0

        // Partition children: measure fixed, count flexible
        var fixedHeight: Float = 0
        var flexCount = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else {
                fixedHeight += child.cachedIntrinsicHeight
            }
        }

        let remainingHeight = max(0, contentHeight - fixedHeight - totalSpacing)
        let flexibleShare = flexCount == 0 ? Float(0) : remainingHeight / Float(flexCount)

        // Layout pass: assign positions top-to-bottom
        var currentY = contentY

        for child in children {
            let childHeight: Float
            if child.isFlexible {
                childHeight = flexibleShare
            } else {
                childHeight = child.fixedHeight ?? child.cachedIntrinsicHeight
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

        var fixedWidth: Float = 0
        var flexCount = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else {
                fixedWidth += child.cachedIntrinsicWidth
            }
        }

        let remainingWidth = max(0, contentWidth - fixedWidth - totalSpacing)
        let flexibleShare = flexCount == 0 ? Float(0) : remainingWidth / Float(flexCount)

        var currentX = contentX

        for child in children {
            let childWidth: Float
            if child.isFlexible {
                childWidth = flexibleShare
            } else {
                childWidth = child.fixedWidth ?? child.cachedIntrinsicWidth
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

    // MARK: - Horizontal Stack (Baseline Alignment)

    /// Layout children horizontally, aligned to their text baselines.
    /// This ensures that text of different sizes lines up on the same baseline.
    private static func layoutHorizontalStackBaseline(
        children: [LayoutNode],
        contentX: Float, contentY: Float,
        contentWidth: Float, contentHeight: Float,
        spacing: Float
    ) {
        let totalSpacing = children.count > 1 ? Float(children.count - 1) * spacing : 0

        var fixedWidth: Float = 0
        var flexCount = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else {
                fixedWidth += child.cachedIntrinsicWidth
            }
        }

        let remainingWidth = max(0, contentWidth - fixedWidth - totalSpacing)
        let flexibleShare = flexCount == 0 ? Float(0) : remainingWidth / Float(flexCount)

        // First pass: assign widths and heights, calculate baselines
        var childSizes: [(width: Float, height: Float)] = []
        for child in children {
            let w = child.isFlexible ? flexibleShare : (child.fixedWidth ?? child.cachedIntrinsicWidth)
            let h = child.fixedHeight ?? child.cachedIntrinsicHeight
            childSizes.append((w, h))
        }

        // Find the maximum baseline offset to align all children
        var maxBaseline: Float = 0
        for (i, child) in children.enumerated() {
            child.width = childSizes[i].width
            child.height = childSizes[i].height
            maxBaseline = max(maxBaseline, child.baselineOffset)
        }

        // Second pass: position children with baseline alignment
        var currentX = contentX
        for (i, child) in children.enumerated() {
            let baseline = child.baselineOffset
            let baselineShift = maxBaseline - baseline

            child.x = currentX
            child.y = contentY + baselineShift
            child.width = childSizes[i].width
            child.height = childSizes[i].height

            layoutChildren(of: child)
            currentX += childSizes[i].width + spacing
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

    // MARK: - Flex Wrap (Horizontal)

    /// Layout children in a wrapping horizontal flow.
    /// Items fill left-to-right, wrapping to the next row when they exceed the content width.
    public static func layoutFlexWrap(
        children: [LayoutNode],
        contentX: Float, contentY: Float,
        contentWidth: Float, contentHeight: Float,
        spacing: Float,
        lineSpacing: Float
    ) {
        var currentX = contentX
        var currentY = contentY
        var rowHeight: Float = 0

        for child in children {
            let childWidth = child.fixedWidth ?? child.cachedIntrinsicWidth
            let childHeight = child.fixedHeight ?? child.cachedIntrinsicHeight

            // Wrap to next line if this child exceeds the row
            if currentX + childWidth > contentX + contentWidth && currentX > contentX {
                currentX = contentX
                currentY += rowHeight + lineSpacing
                rowHeight = 0
            }

            child.x = currentX
            child.y = currentY
            child.width = childWidth
            child.height = childHeight

            layoutChildren(of: child)

            currentX += childWidth + spacing
            rowHeight = max(rowHeight, childHeight)
        }
    }
}
