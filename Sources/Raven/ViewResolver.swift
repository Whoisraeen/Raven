// MARK: - ViewResolver

/// Converts a `View` hierarchy into a `LayoutNode` tree.
/// This is the bridge between the declarative API and the layout engine.
public enum ViewResolver {

    /// Resolve any View into a LayoutNode tree.
    public static func resolve<V: View>(_ view: V, path: String = "root") -> LayoutNode {
        // Check for primitive views first (the terminal nodes)
        if let node = resolvePrimitive(view, path: path) {
            node.id = path
            return node
        }

        // For composite views, resolve the body
        let node = resolve(view.body, path: path)
        node.id = path
        return node
    }

    /// Attempt to resolve a view as a primitive (known type).
    private static func resolvePrimitive<V: View>(_ view: V, path: String) -> LayoutNode? {
        // Never / EmptyView
        if view is EmptyView || view is Never {
            let node = LayoutNode()
            node.id = path
            return node
        }

        // Text
        if let textView = view as? Text {
            let node = resolveText(textView)
            node.id = path
            return node
        }

        // Button
        if let buttonView = view as? Button {
            let node = resolveButton(buttonView)
            node.id = path
            return node
        }

        // Image
        if let imageView = view as? Image {
            let node = resolveImage(imageView)
            node.id = path
            return node
        }

        // Spacer
        if view is Spacer {
            let node = resolveSpacer()
            node.id = path
            return node
        }

        // TextField
        if let textField = view as? TextField {
            let node = resolveTextField(textField)
            node.id = path
            return node
        }

        // VStack
        if let vstack = view as? VStack {
            let node = resolveVStack(vstack, path: path)
            node.id = path
            return node
        }

        // HStack
        if let hstack = view as? HStack {
            let node = resolveHStack(hstack, path: path)
            node.id = path
            return node
        }

        // ZStack
        if let zstack = view as? ZStack {
            let node = resolveZStack(zstack, path: path)
            node.id = path
            return node
        }

        // ScrollView
        if let scrollView = view as? ScrollView {
            let node = resolveScrollView(scrollView, path: path)
            node.id = path
            return node
        }

        // ModifiedView
        if let resolved = resolveModifiedView(view, path: path) {
            return resolved
        }

        // TupleViews
        if let resolved = resolveTupleView(view, path: path) {
            return resolved
        }

        // OptionalView
        if let resolved = resolveOptionalView(view, path: path) {
            return resolved
        }

        // ConditionalView
        if let resolved = resolveConditionalView(view, path: path) {
            return resolved
        }

        return nil
    }

    // MARK: - Primitives

    private static func resolveText(_ text: Text) -> LayoutNode {
        let node = LayoutNode()
        node.text = text.content
        node.foregroundColor = text.color ?? .text
        node.backgroundColor = nil
        node.accessibilityRole = .text
        node.accessibilityLabel = text.content
        return node
    }

    private static func resolveButton(_ button: Button) -> LayoutNode {
        let node = LayoutNode()
        node.backgroundColor = button.backgroundColor ?? .primary
        node.cornerRadius = 6
        node.onTap = button.action
        
        let textNode = LayoutNode()
        textNode.text = button.title
        textNode.foregroundColor = .buttonText
        textNode.padding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        
        node.children = [textNode]
        node.accessibilityRole = .button
        node.accessibilityLabel = button.title
        return node
    }

    private static func resolveImage(_ image: Image) -> LayoutNode {
        let node = LayoutNode()
        node.imageSource = image.path
        node.imageOpacity = image.opacity
        node.accessibilityRole = .image
        node.accessibilityLabel = image.path
        return node
    }

    private static func resolveSpacer() -> LayoutNode {
        let node = LayoutNode()
        node.isFlexible = true
        return node
    }

    private static func resolveTextField(_ textField: TextField) -> LayoutNode {
        let node = LayoutNode()
        node.isTextField = true
        node.textFieldBinding = textField.text
        node.textFieldPlaceholder = textField.placeholder
        node.textFieldId = textField.id
        node.backgroundColor = .surface
        node.cornerRadius = 4
        node.padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        node.accessibilityRole = .textField
        node.accessibilityValue = textField.text.value
        
        if node.fixedWidth == nil { node.fixedWidth = 200 }
        return node
    }

    // MARK: - ScrollView

    private static func resolveScrollView(_ scrollView: ScrollView, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.isScrollView = true
        node.scrollAxis = scrollView.axis
        node.scrollOffset = scrollView.scrollOffset.value
        node.scrollStateVar = scrollView.scrollOffset

        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.spacing = 0
        contentNode.id = "\(path).sv"
        contentNode.children = scrollView.content.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).s\(index)")
        }

        node.children = [contentNode]
        return node
    }

    /// Resolve a type-erased View.
    private static func resolveAnyView(_ view: any View, path: String) -> LayoutNode {
        func resolveImpl<V: View>(_ v: V) -> LayoutNode {
            return ViewResolver.resolve(v, path: path)
        }
        return resolveImpl(view)
    }

    // MARK: - Stacks

    private static func resolveVStack(_ vstack: VStack, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.spacing = vstack.spacing
        node.horizontalAlignment = vstack.alignment
        node.children = vstack.resolvedChildren(path: path)
        return node
    }

    private static func resolveHStack(_ hstack: HStack, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .horizontal
        node.spacing = hstack.spacing
        node.verticalAlignment = hstack.alignment
        node.children = hstack.resolvedChildren(path: path)
        return node
    }

    private static func resolveZStack(_ zstack: ZStack, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .zStack
        node.children = zstack.resolvedChildren(path: path)
        return node
    }

    // MARK: - TupleViews

    private static func resolveTupleView<V: View>(_ view: V, path: String) -> LayoutNode? {
        var children: [LayoutNode] = []
        if let tupleView = view as? AnyTupleView {
            children = tupleView.childrenViews.enumerated().map { index, childView in
                resolveAnyView(childView as! (any View), path: "\(path).\(index)")
            }
        } else { return nil }

        let node = LayoutNode()
        node.stackAxis = .vertical
        node.spacing = 0
        node.children = children
        return node
    }

    // MARK: - ModifiedView

    private static func resolveModifiedView<V: View>(_ view: V, path: String) -> LayoutNode? {
        guard let modified = view as? AnyModifiedView else { return nil }
        return modified.resolveModified(path: path)
    }

    // MARK: - Optional / Conditional

    private static func resolveOptionalView<V: View>(_ view: V, path: String) -> LayoutNode? {
        guard let optional = view as? AnyOptionalView else { return nil }
        return optional.resolveOptional(path: path)
    }

    private static func resolveConditionalView<V: View>(_ view: V, path: String) -> LayoutNode? {
        guard let conditional = view as? AnyConditionalView else { return nil }
        return conditional.resolveConditional(path: path)
    }
}

// MARK: - Type Erasure Protocols for ViewResolver

protocol AnyModifiedView { func resolveModified(path: String) -> LayoutNode }
protocol AnyOptionalView { func resolveOptional(path: String) -> LayoutNode }
protocol AnyConditionalView { func resolveConditional(path: String) -> LayoutNode }

extension ModifiedView: AnyModifiedView {
    func resolveModified(path: String) -> LayoutNode {
        let node = ViewResolver.resolve(content, path: "\(path).m")
        modifier.apply(to: node)
        return node
    }
}

extension OptionalView: AnyOptionalView {
    func resolveOptional(path: String) -> LayoutNode {
        if let content = content {
            return ViewResolver.resolve(content, path: "\(path).o")
        }
        let node = LayoutNode()
        node.id = "\(path).o"
        return node
    }
}

extension ConditionalView: AnyConditionalView {
    func resolveConditional(path: String) -> LayoutNode {
        switch storage {
        case .trueContent(let view):
            return ViewResolver.resolve(view, path: "\(path).ct")
        case .falseContent(let view):
            return ViewResolver.resolve(view, path: "\(path).cf")
        }
    }
}
