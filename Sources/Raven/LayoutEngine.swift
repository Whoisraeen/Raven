import Foundation

// MARK: - LayoutEngine

/// Resolves a LayoutNode tree by assigning positions and sizes.
/// Uses a two-pass approach:
/// 1. Measure (bottom-up) — calculate intrinsic sizes (with caching), parallelized for independent subtrees
/// 2. Layout (top-down) — assign positions based on parent constraints
///
/// Optimizations:
/// - Intrinsic size caching: each node caches its measured size and only recalculates when dirty
/// - Subtree pruning: clean subtrees skip relayout entirely
/// - Parallel measure: top-level children are measured concurrently when the tree is wide enough
public enum LayoutEngine {

    /// Minimum number of children to justify parallel measurement overhead.
    private static let parallelThreshold = 4

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

        // Pass 1: Parallel measure — pre-compute intrinsic sizes for independent subtrees.
        // The measure pass is pure (reads node properties, calls FontManager which is thread-safe).
        // We parallelize at the top level(s) where the tree is widest.
        parallelMeasure(node: root)

        // Pass 2: Layout — assign positions top-down (sequential, position-dependent).
        layoutChildren(of: root)

        // Mark the entire tree as clean after layout
        root.markLayoutClean()
    }

    // MARK: - Parallel Measure Pass

    /// Pre-compute intrinsic sizes for independent subtrees in parallel.
    /// Each subtree's measure is pure (no side effects beyond caching), so
    /// sibling subtrees can be measured concurrently.
    private static func parallelMeasure(node: LayoutNode) {
        let children = node.children
        guard !children.isEmpty else { return }

        if children.count >= parallelThreshold {
            // Measure sibling subtrees concurrently.
            // Safety: LayoutNode is a reference type owned by the single UI thread.
            // concurrentPerform is synchronous — all work completes before returning,
            // and each iteration operates on a disjoint subtree (no shared mutation).
            nonisolated(unsafe) let unsafeChildren = children
            DispatchQueue.concurrentPerform(iterations: children.count) { index in
                prewarmIntrinsicSizes(node: unsafeChildren[index])
            }
        } else {
            for child in children {
                prewarmIntrinsicSizes(node: child)
            }
        }
    }

    /// Recursively compute and cache intrinsic sizes bottom-up.
    /// Visits children first (so their cached values are ready), then triggers
    /// this node's cachedIntrinsicWidth/Height which reads from children.
    private static func prewarmIntrinsicSizes(node: LayoutNode) {
        let children = node.children

        if children.count >= parallelThreshold {
            nonisolated(unsafe) let unsafeChildren = children
            DispatchQueue.concurrentPerform(iterations: children.count) { index in
                prewarmIntrinsicSizes(node: unsafeChildren[index])
            }
        } else {
            for child in children {
                prewarmIntrinsicSizes(node: child)
            }
        }

        // Now compute this node's intrinsic size (reads children's cached values)
        let _ = node.cachedIntrinsicWidth
        let _ = node.cachedIntrinsicHeight
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

        // Classify children: fixed (fixedHeight), flexible (Spacer), expandable (neither)
        var totalFixed: Float = 0
        var flexCount = 0
        var expandableCount = 0
        var totalExpandableIntrinsic: Float = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else if let fh = child.fixedHeight {
                totalFixed += fh
            } else {
                let ih = child.cachedIntrinsicHeight
                totalExpandableIntrinsic += ih
                expandableCount += 1
            }
        }

        let usedHeight = totalFixed + totalExpandableIntrinsic + totalSpacing
        let remainingHeight = max(0, contentHeight - usedHeight)

        let flexibleShare = flexCount > 0 ? remainingHeight / Float(flexCount) : Float(0)

        // When no flexible children, expandable children absorb remaining space
        let expandableBonus: Float
        if flexCount == 0 && expandableCount > 0 && remainingHeight > 0 {
            expandableBonus = remainingHeight / Float(expandableCount)
        } else {
            expandableBonus = 0
        }

        // Layout pass: assign positions top-to-bottom
        var currentY = contentY

        for child in children {
            let childHeight: Float
            if child.isFlexible {
                childHeight = flexibleShare
            } else if let fh = child.fixedHeight {
                childHeight = fh
            } else {
                childHeight = child.cachedIntrinsicHeight + expandableBonus
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

        // Classify children into three categories:
        // 1. Fixed: has fixedWidth — gets exact width
        // 2. Flexible: isFlexible (Spacer) — shares remaining space
        // 3. Expandable: no fixedWidth, not flexible — gets intrinsic width,
        //    but absorbs remaining space when there are no flexible children
        var totalFixed: Float = 0
        var flexCount = 0
        var expandableCount = 0
        var totalExpandableIntrinsic: Float = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else if let fw = child.fixedWidth {
                totalFixed += fw
            } else {
                let iw = child.cachedIntrinsicWidth
                totalExpandableIntrinsic += iw
                expandableCount += 1
            }
        }

        let usedWidth = totalFixed + totalExpandableIntrinsic + totalSpacing
        let remainingWidth = max(0, contentWidth - usedWidth)

        // Flexible children share remaining after all fixed + expandable intrinsic
        let flexibleShare = flexCount > 0 ? remainingWidth / Float(flexCount) : Float(0)

        // When no flexible children exist, expandable children absorb remaining space
        let expandableBonus: Float
        if flexCount == 0 && expandableCount > 0 && remainingWidth > 0 {
            expandableBonus = remainingWidth / Float(expandableCount)
        } else {
            expandableBonus = 0
        }

        var currentX = contentX

        for child in children {
            let childWidth: Float
            if child.isFlexible {
                childWidth = flexibleShare
            } else if let fw = child.fixedWidth {
                childWidth = fw
            } else {
                childWidth = child.cachedIntrinsicWidth + expandableBonus
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

        var totalFixed: Float = 0
        var flexCount = 0
        var expandableCount = 0
        var totalExpandableIntrinsic: Float = 0

        for child in children {
            if child.isFlexible {
                flexCount += 1
            } else if let fw = child.fixedWidth {
                totalFixed += fw
            } else {
                let iw = child.cachedIntrinsicWidth
                totalExpandableIntrinsic += iw
                expandableCount += 1
            }
        }

        let usedWidth = totalFixed + totalExpandableIntrinsic + totalSpacing
        let remainingWidth = max(0, contentWidth - usedWidth)
        let flexibleShare = flexCount > 0 ? remainingWidth / Float(flexCount) : Float(0)

        let expandableBonus: Float
        if flexCount == 0 && expandableCount > 0 && remainingWidth > 0 {
            expandableBonus = remainingWidth / Float(expandableCount)
        } else {
            expandableBonus = 0
        }

        // First pass: assign widths and heights, calculate baselines
        var childSizes: [(width: Float, height: Float)] = []
        for child in children {
            let w: Float
            if child.isFlexible {
                w = flexibleShare
            } else if let fw = child.fixedWidth {
                w = fw
            } else {
                w = child.cachedIntrinsicWidth + expandableBonus
            }
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
