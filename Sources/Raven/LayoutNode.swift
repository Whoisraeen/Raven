// MARK: - LayoutNode

/// The intermediate representation of a resolved view.
/// The layout engine populates position and size, then the render
/// collector flattens the tree into drawable quads.
public class LayoutNode {
    /// Absolute position (top-left corner)
    public var x: Float = 0 {
        didSet { if oldValue != x { animate(.x, from: oldValue, to: x) } }
    }
    public var y: Float = 0 {
        didSet { if oldValue != y { animate(.y, from: oldValue, to: y) } }
    }

    /// Resolved size
    public var width: Float = 0
    public var height: Float = 0

    /// Visual properties
    public var opacity: Float = 1.0 {
        didSet { if oldValue != opacity { animate(.opacity, from: oldValue, to: opacity) } }
    }
    public var scale: Float = 1.0 {
        didSet { if oldValue != scale { animate(.scale, from: oldValue, to: scale) } }
    }
    public var rotation: Float = 0.0 {
        didSet { if oldValue != rotation { animate(.rotation, from: oldValue, to: rotation) } }
    }

    /// Stable identity for reconciliation/animation
    public var id: AnyHashable? = nil

    /// Static cache to persist positions across resolutions for animation
    nonisolated(unsafe) internal static var previousPositions: [AnyHashable: (x: Float, y: Float)] = [:]

    /// Visual properties
    public var backgroundColor: Color? = nil
    public var foregroundColor: Color? = nil
    public var cornerRadius: Float = 0

    /// Border
    public var borderColor: Color? = nil
    public var borderWidth: Float = 0

    /// Hidden — when true, node is not rendered
    public var isHidden: Bool = false

    /// Disabled — when true, interaction is suppressed and opacity reduced
    public var isDisabled: Bool = false

    /// Shadow properties
    public var shadowColor: Color? = nil
    public var shadowRadius: Float = 0
    public var shadowOffsetX: Float = 0
    public var shadowOffsetY: Float = 0

    /// Text content (for Text nodes)
    public var text: String? = nil

    /// Layout properties
    public var padding: EdgeInsets = EdgeInsets()
    public var fixedWidth: Float? = nil
    public var fixedHeight: Float? = nil
    public var minWidth: Float? = nil
    public var minHeight: Float? = nil

    /// Stack layout properties
    public var stackAxis: StackAxis? = nil
    public var spacing: Float = 0
    public var horizontalAlignment: HorizontalAlignment = .center
    public var verticalAlignment: VerticalAlignment = .center

    /// Flexible (expands to fill available space)
    public var isFlexible: Bool = false

    /// Flex wrap — when true in a horizontal stack, children wrap to the next line
    public var flexWrap: Bool = false

    /// Line spacing for wrapped flex layouts
    public var lineSpacing: Float = 8

    /// Alignment baseline — aligns children to their text baseline in horizontal stacks
    public var alignToBaseline: Bool = false

    /// Event handlers
    public var onTap: (@Sendable () -> Void)? = nil

    /// Lifecycle callbacks
    public var onAppear: (@Sendable () -> Void)? = nil
    public var onDisappear: (@Sendable () -> Void)? = nil

    /// Font size for text rendering
    public var fontSize: Float = 16.0

    /// Maximum text width for word wrapping (nil = no wrapping)
    public var maxTextWidth: Float? = nil

    /// Baseline offset from top of node (for text baseline alignment).
    /// For text nodes, this is the distance from the top to the text baseline.
    public var baselineOffset: Float {
        if text != nil {
            // Approximate: baseline is ~75% of font height from top
            let textSize = FontManager.shared.measureText(text ?? "Ay", fontSize: fontSize)
            return padding.top + textSize.height * 0.75
        }
        // For containers, use the first text child's baseline
        for child in children {
            if child.text != nil {
                return child.y - y + child.baselineOffset
            }
        }
        return cachedIntrinsicHeight * 0.75
    }

    /// Image source path (for Image nodes)
    public var imageSource: String? = nil
    public var imageOpacity: Float = 1.0

    /// TextField properties
    public var isTextField: Bool = false
    public var textFieldBinding: Binding<String>? = nil
    public var textFieldPlaceholder: String = ""
    public var textFieldId: String? = nil

    /// ScrollView properties
    public var isScrollView: Bool = false
    public var scrollOffset: Float = 0
    public var scrollAxis: ScrollAxis? = nil
    public var scrollStateVar: StateVar<Float>? = nil

    /// Accessibility properties
    public var accessibilityRole: AccessibilityRole = .none
    public var accessibilityLabel: String? = nil
    public var accessibilityValue: String? = nil
    public var accessibilityHint: String? = nil
    public var isAccessibilityHidden: Bool = false

    /// Platform traits (for native feel/behavioral differences)
    public var platform: Platform = .windows

    /// Children
    public var children: [LayoutNode] = []

    /// Find a node by its unique path/ID.
    public func findNode(by path: String) -> LayoutNode? {
        if let id = self.id as? String, id == path { return self }
        for child in children {
            if let found = child.findNode(by: path) {
                return found
            }
        }
        return nil
    }

    public init() {}

    // MARK: - Intrinsic Size Cache

    private var _cachedIntrinsicWidth: Float? = nil
    private var _cachedIntrinsicHeight: Float? = nil

    /// Cached intrinsic width — computed once per layout pass, then reused.
    public var cachedIntrinsicWidth: Float {
        if let cached = _cachedIntrinsicWidth { return cached }
        let value = intrinsicWidth
        _cachedIntrinsicWidth = value
        return value
    }

    /// Cached intrinsic height — computed once per layout pass, then reused.
    public var cachedIntrinsicHeight: Float {
        if let cached = _cachedIntrinsicHeight { return cached }
        let value = intrinsicHeight
        _cachedIntrinsicHeight = value
        return value
    }

    /// Invalidate cached sizes (called when a node is marked dirty).
    public func invalidateIntrinsicSize() {
        _cachedIntrinsicWidth = nil
        _cachedIntrinsicHeight = nil
        // Bubble up — parent sizes depend on children
        // (Not needed during full rebuild since all nodes are new)
    }

    /// The ideal/intrinsic size of this node (before layout assigns a final size)
    public var intrinsicWidth: Float {
        if let fw = fixedWidth { return fw }
        if let text = text {
            let textSize = FontManager.shared.measureText(text, fontSize: fontSize)
            return textSize.width + padding.leading + padding.trailing
        }
        switch stackAxis {
        case .horizontal:
            let childrenWidth = children.reduce(Float(0)) { $0 + $1.intrinsicWidth }
            let spacingTotal = children.count > 1 ? Float(children.count - 1) * spacing : 0
            return childrenWidth + spacingTotal + padding.leading + padding.trailing
        case .vertical:
            let maxChildWidth = children.map { $0.intrinsicWidth }.max() ?? 0
            return maxChildWidth + padding.leading + padding.trailing
        case .zStack:
            let maxChildWidth = children.map { $0.intrinsicWidth }.max() ?? 0
            return maxChildWidth + padding.leading + padding.trailing
        case nil:
            if !children.isEmpty {
                return (children.map { $0.intrinsicWidth }.max() ?? 0)
                    + padding.leading + padding.trailing
            }
            return padding.leading + padding.trailing
        }
    }

    public var intrinsicHeight: Float {
        if let fh = fixedHeight { return fh }
        if let text = text {
            let wrapWidth = maxTextWidth ?? 0
            let textSize = FontManager.shared.measureText(text, fontSize: fontSize, maxWidth: wrapWidth)
            return textSize.height + padding.top + padding.bottom
        }
        switch stackAxis {
        case .horizontal:
            let maxChildHeight = children.map { $0.intrinsicHeight }.max() ?? 0
            return maxChildHeight + padding.top + padding.bottom
        case .vertical:
            let childrenHeight = children.reduce(Float(0)) { $0 + $1.intrinsicHeight }
            let spacingTotal = children.count > 1 ? Float(children.count - 1) * spacing : 0
            return childrenHeight + spacingTotal + padding.top + padding.bottom
        case .zStack:
            let maxChildHeight = children.map { $0.intrinsicHeight }.max() ?? 0
            return maxChildHeight + padding.top + padding.bottom
        case nil:
            if !children.isEmpty {
                return (children.map { $0.intrinsicHeight }.max() ?? 0)
                    + padding.top + padding.bottom
            }
            return padding.top + padding.bottom
        }
    }
    // MARK: - Animation Support

    private func animate(_ property: AnimatableProperty, from start: Float, to target: Float) {
        guard let animation = AnimationEngine.shared.currentAnimation else { return }
        
        // If we have a stable ID, we can check if we should override the 'start' value
        // with the value from the previous frame to ensure continuity.
        var effectiveStart = start
        if let id = self.id, let prev = LayoutNode.previousPositions[id] {
            switch property {
            case .x: effectiveStart = prev.x
            case .y: effectiveStart = prev.y
            default: break
            }
        }

        let instance = AnimationInstance(
            node: self,
            property: property,
            startValue: effectiveStart,
            targetValue: target,
            animation: animation
        )
        AnimationEngine.shared.addAnimation(instance)
    }
}

// MARK: - StackAxis

public enum StackAxis: Sendable {
    case horizontal
    case vertical
    case zStack
}
