// MARK: - View Modifiers

/// Padding modifier
public struct PaddingModifier: ViewModifier {
    public let insets: EdgeInsets
    public func apply(to node: LayoutNode) {
        node.padding = EdgeInsets(
            top: node.padding.top + insets.top,
            leading: node.padding.leading + insets.leading,
            bottom: node.padding.bottom + insets.bottom,
            trailing: node.padding.trailing + insets.trailing
        )
    }
}

/// Background color modifier
public struct BackgroundModifier: ViewModifier {
    public let color: Color
    public func apply(to node: LayoutNode) {
        node.backgroundColor = color
    }
}

/// Foreground color modifier
public struct ForegroundModifier: ViewModifier {
    public let color: Color
    public func apply(to node: LayoutNode) {
        node.foregroundColor = color
    }
}

/// Fixed frame modifier
public struct FrameModifier: ViewModifier {
    public let width: Float?
    public let height: Float?
    public func apply(to node: LayoutNode) {
        if let w = width { node.fixedWidth = w }
        if let h = height { node.fixedHeight = h }
    }
}

/// Corner radius modifier
public struct CornerRadiusModifier: ViewModifier {
    public let radius: Float
    public func apply(to node: LayoutNode) {
        node.cornerRadius = radius
    }
}

// MARK: - View Extension Methods

extension View {
    /// Add padding around the view.
    public func padding(_ value: Float) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(insets: EdgeInsets(value)))
    }

    /// Add padding with specific edge insets.
    public func padding(_ insets: EdgeInsets) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(insets: insets))
    }

    /// Add padding on specific edges.
    public func padding(top: Float = 0, leading: Float = 0, bottom: Float = 0, trailing: Float = 0) -> ModifiedView<Self, PaddingModifier> {
        ModifiedView(content: self, modifier: PaddingModifier(
            insets: EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        ))
    }

    /// Set the background color.
    public func background(_ color: Color) -> ModifiedView<Self, BackgroundModifier> {
        ModifiedView(content: self, modifier: BackgroundModifier(color: color))
    }

    /// Set the foreground (text) color.
    public func foreground(_ color: Color) -> ModifiedView<Self, ForegroundModifier> {
        ModifiedView(content: self, modifier: ForegroundModifier(color: color))
    }

    /// Set a fixed frame size.
    public func frame(width: Float? = nil, height: Float? = nil) -> ModifiedView<Self, FrameModifier> {
        ModifiedView(content: self, modifier: FrameModifier(width: width, height: height))
    }

    /// Set the corner radius.
    public func cornerRadius(_ radius: Float) -> ModifiedView<Self, CornerRadiusModifier> {
        ModifiedView(content: self, modifier: CornerRadiusModifier(radius: radius))
    }
}
