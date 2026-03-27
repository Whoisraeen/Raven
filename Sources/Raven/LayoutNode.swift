// MARK: - LayoutNode

/// The intermediate representation of a resolved view.
/// The layout engine populates position and size, then the render
/// collector flattens the tree into drawable quads.
public class LayoutNode {
    /// Absolute position (top-left corner)
    public var x: Float = 0
    public var y: Float = 0

    /// Resolved size
    public var width: Float = 0
    public var height: Float = 0

    /// Visual properties
    public var backgroundColor: Color? = nil
    public var foregroundColor: Color? = nil
    public var cornerRadius: Float = 0

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

    /// Event handlers
    public var onTap: (@Sendable () -> Void)? = nil

    /// Font size for text rendering
    public var fontSize: Float = 16.0

    /// Image source path (for Image nodes)
    public var imageSource: String? = nil
    public var imageOpacity: Float = 1.0

    /// TextField properties
    public var isTextField: Bool = false
    public var textFieldBinding: Binding<String>? = nil
    public var textFieldPlaceholder: String = ""
    public var textFieldId: ObjectIdentifier? = nil

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

    /// Children
    public var children: [LayoutNode] = []

    public init() {}

    /// The ideal/intrinsic size of this node (before layout assigns a final size)
    public var intrinsicWidth: Float {
        if let fw = fixedWidth { return fw }
        if let text = text {
            let textSize = FontManager.shared.measureText(text, fontSize: 16.0)
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
            let textSize = FontManager.shared.measureText(text, fontSize: 16.0)
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
}

// MARK: - StackAxis

public enum StackAxis: Sendable {
    case horizontal
    case vertical
    case zStack
}
