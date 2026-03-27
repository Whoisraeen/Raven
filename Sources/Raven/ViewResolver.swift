// MARK: - ViewResolver

/// Converts a `View` hierarchy into a `LayoutNode` tree.
/// This is the bridge between the declarative API and the layout engine.
public enum ViewResolver {

    /// Resolve any View into a LayoutNode tree.
    public static func resolve<V: View>(_ view: V) -> LayoutNode {
        // Check for primitive views first (the terminal nodes)
        if let node = resolvePrimitive(view) {
            return node
        }

        // For composite views, resolve the body
        return resolve(view.body)
    }

    /// Attempt to resolve a view as a primitive (known type).
    /// Returns nil if the view is not a primitive and should
    /// be resolved via its `body` property.
    private static func resolvePrimitive<V: View>(_ view: V) -> LayoutNode? {
        // Never / EmptyView
        if view is EmptyView {
            return LayoutNode()
        }
        if view is Never {
            return LayoutNode()
        }

        // Text
        if let textView = view as? Text {
            return resolveText(textView)
        }

        // Button
        if let buttonView = view as? Button {
            return resolveButton(buttonView)
        }

        // Image
        if let imageView = view as? Image {
            return resolveImage(imageView)
        }

        // Spacer
        if view is Spacer {
            return resolveSpacer()
        }

        // TextField
        if let textField = view as? TextField {
            return resolveTextField(textField)
        }

        // VStack
        if let vstack = view as? VStack {
            return resolveVStack(vstack)
        }

        // ScrollView
        if let scrollView = view as? ScrollView {
            return resolveScrollView(scrollView)
        }

        // HStack
        if let hstack = view as? HStack {
            return resolveHStack(hstack)
        }

        // ZStack
        if let zstack = view as? ZStack {
            return resolveZStack(zstack)
        }

        // TupleViews — extract children
        if let resolved = resolveTupleView(view) {
            return resolved
        }

        // ModifiedView — resolve content and apply modifier
        if let resolved = resolveModifiedView(view) {
            return resolved
        }

        // OptionalView
        if let resolved = resolveOptionalView(view) {
            return resolved
        }

        // ConditionalView
        if let resolved = resolveConditionalView(view) {
            return resolved
        }

        return nil
    }

    // MARK: - Primitives

    private static func resolveText(_ text: Text) -> LayoutNode {
        let node = LayoutNode()
        node.text = text.content
        node.foregroundColor = text.color ?? .text
        // Placeholder background to visualize text area
        node.backgroundColor = nil
        
        node.accessibilityRole = .text
        node.accessibilityLabel = text.content
        return node
    }

    private static func resolveButton(_ button: Button) -> LayoutNode {
        let node = LayoutNode()
        node.backgroundColor = button.backgroundColor ?? .primary
        node.cornerRadius = 6
        node.padding = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        node.onTap = button.action  // Attach action for event dispatch

        node.accessibilityRole = .button
        node.accessibilityLabel = button.label

        let labelNode = LayoutNode()
        labelNode.text = button.label
        labelNode.foregroundColor = button.foregroundColor ?? .white
        labelNode.accessibilityRole = .text
        labelNode.accessibilityLabel = button.label
        labelNode.isAccessibilityHidden = true // hide child label, parent button handles it
        node.children = [labelNode]

        return node
    }

    private static func resolveSpacer() -> LayoutNode {
        let node = LayoutNode()
        node.isFlexible = true
        return node
    }

    private static func resolveImage(_ imageView: Image) -> LayoutNode {
        let node = LayoutNode()
        node.imageSource = imageView.source
        node.imageOpacity = imageView.opacity
        node.accessibilityRole = .image

        // Use explicit size or defaults (natural size will be resolved at render time)
        if let w = imageView.displayWidth { node.fixedWidth = w }
        if let h = imageView.displayHeight { node.fixedHeight = h }

        // Default size for images without explicit frame — 100x100 placeholder
        if node.fixedWidth == nil { node.fixedWidth = 100 }
        if node.fixedHeight == nil { node.fixedHeight = 100 }

        return node
    }

    private static func resolveTextField(_ textField: TextField) -> LayoutNode {
        let node = LayoutNode()
        node.isTextField = true
        node.textFieldBinding = textField.text
        node.textFieldPlaceholder = textField.placeholder
        
        node.accessibilityRole = .textField
        node.accessibilityLabel = textField.placeholder
        node.accessibilityValue = textField.text.wrappedValue

        node.textFieldId = ObjectIdentifier(node)

        // Show current text or placeholder
        let currentText = textField.text.wrappedValue
        node.text = currentText.isEmpty ? textField.placeholder : currentText

        // Style defaults
        node.backgroundColor = textField.backgroundColor ?? .surface
        node.foregroundColor = textField.textColor ?? .text
        node.cornerRadius = 4
        node.padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)

        // Default width for text fields
        if node.fixedWidth == nil { node.fixedWidth = 200 }

        return node
    }

    // MARK: - ScrollView

    private static func resolveScrollView(_ scrollView: ScrollView) -> LayoutNode {
        let node = LayoutNode()
        node.isScrollView = true
        node.scrollAxis = scrollView.axis
        node.scrollOffset = scrollView.scrollOffset.value
        node.scrollStateVar = scrollView.scrollOffset

        // Resolve children into a VStack-like container
        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.spacing = 0
        contentNode.children = scrollView.content.map { child in
            resolveAnyView(child)
        }

        node.children = [contentNode]
        return node
    }

    /// Resolve a type-erased View.
    private static func resolveAnyView(_ view: any View) -> LayoutNode {
        // Use the body to get a concrete type we can resolve
        func resolveImpl<V: View>(_ v: V) -> LayoutNode {
            return ViewResolver.resolve(v)
        }
        return resolveImpl(view)
    }

    // MARK: - Stacks

    private static func resolveVStack(_ vstack: VStack) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.spacing = vstack.spacing
        node.horizontalAlignment = vstack.alignment
        node.children = vstack.resolvedChildren()
        return node
    }

    private static func resolveHStack(_ hstack: HStack) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .horizontal
        node.spacing = hstack.spacing
        node.verticalAlignment = hstack.alignment
        node.children = hstack.resolvedChildren()
        return node
    }

    private static func resolveZStack(_ zstack: ZStack) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .zStack
        node.children = zstack.resolvedChildren()
        return node
    }

    // MARK: - TupleViews

    private static func resolveTupleView<V: View>(_ view: V) -> LayoutNode? {
        var children: [LayoutNode] = []

        if let tv2 = view as? AnyTupleView2 {
            children = tv2.resolveChildren()
        } else if let tv3 = view as? AnyTupleView3 {
            children = tv3.resolveChildren()
        } else if let tv4 = view as? AnyTupleView4 {
            children = tv4.resolveChildren()
        } else if let tv5 = view as? AnyTupleView5 {
            children = tv5.resolveChildren()
        } else if let tv6 = view as? AnyTupleView6 {
            children = tv6.resolveChildren()
        } else {
            return nil
        }

        // A bare TupleView acts as a vertical stack with 0 spacing
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.spacing = 0
        node.children = children
        return node
    }

    // MARK: - ModifiedView

    private static func resolveModifiedView<V: View>(_ view: V) -> LayoutNode? {
        guard let modified = view as? AnyModifiedView else { return nil }
        return modified.resolveModified()
    }

    // MARK: - Optional / Conditional

    private static func resolveOptionalView<V: View>(_ view: V) -> LayoutNode? {
        guard let optional = view as? AnyOptionalView else { return nil }
        return optional.resolveOptional()
    }

    private static func resolveConditionalView<V: View>(_ view: V) -> LayoutNode? {
        guard let conditional = view as? AnyConditionalView else { return nil }
        return conditional.resolveConditional()
    }
}

// MARK: - Type Erasure Protocols for ViewResolver

/// These protocols allow ViewResolver to inspect generic types
/// without knowing their type parameters at compile time.

protocol AnyTupleView2 { func resolveChildren() -> [LayoutNode] }
protocol AnyTupleView3 { func resolveChildren() -> [LayoutNode] }
protocol AnyTupleView4 { func resolveChildren() -> [LayoutNode] }
protocol AnyTupleView5 { func resolveChildren() -> [LayoutNode] }
protocol AnyTupleView6 { func resolveChildren() -> [LayoutNode] }
protocol AnyModifiedView { func resolveModified() -> LayoutNode }
protocol AnyOptionalView { func resolveOptional() -> LayoutNode }
protocol AnyConditionalView { func resolveConditional() -> LayoutNode }

extension TupleView2: AnyTupleView2 {
    func resolveChildren() -> [LayoutNode] {
        [ViewResolver.resolve(c0), ViewResolver.resolve(c1)]
    }
}

extension TupleView3: AnyTupleView3 {
    func resolveChildren() -> [LayoutNode] {
        [ViewResolver.resolve(c0), ViewResolver.resolve(c1), ViewResolver.resolve(c2)]
    }
}

extension TupleView4: AnyTupleView4 {
    func resolveChildren() -> [LayoutNode] {
        [ViewResolver.resolve(c0), ViewResolver.resolve(c1), ViewResolver.resolve(c2),
         ViewResolver.resolve(c3)]
    }
}

extension TupleView5: AnyTupleView5 {
    func resolveChildren() -> [LayoutNode] {
        [ViewResolver.resolve(c0), ViewResolver.resolve(c1), ViewResolver.resolve(c2),
         ViewResolver.resolve(c3), ViewResolver.resolve(c4)]
    }
}

extension TupleView6: AnyTupleView6 {
    func resolveChildren() -> [LayoutNode] {
        [ViewResolver.resolve(c0), ViewResolver.resolve(c1), ViewResolver.resolve(c2),
         ViewResolver.resolve(c3), ViewResolver.resolve(c4), ViewResolver.resolve(c5)]
    }
}

extension ModifiedView: AnyModifiedView {
    func resolveModified() -> LayoutNode {
        let node = ViewResolver.resolve(content)
        modifier.apply(to: node)
        return node
    }
}

extension OptionalView: AnyOptionalView {
    func resolveOptional() -> LayoutNode {
        if let content = content {
            return ViewResolver.resolve(content)
        }
        return LayoutNode()  // Empty node
    }
}

extension ConditionalView: AnyConditionalView {
    func resolveConditional() -> LayoutNode {
        switch storage {
        case .trueContent(let view):
            return ViewResolver.resolve(view)
        case .falseContent(let view):
            return ViewResolver.resolve(view)
        }
    }
}
