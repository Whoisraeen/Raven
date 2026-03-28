// MARK: - ViewResolver

/// Converts a `View` hierarchy into a `LayoutNode` tree.
/// This is the bridge between the declarative API and the layout engine.
public enum ViewResolver {

    /// Resolve any View into a LayoutNode tree.
    public static func resolve<V: View>(_ view: V, path: String = "root") -> LayoutNode {
        // Inject @Environment values into the view before resolving
        injectEnvironment(into: view)

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

    /// Inject current environment values into any @Environment properties on the view.
    private static func injectEnvironment(into view: any View) {
        let mirror = Mirror(reflecting: view)
        for child in mirror.children {
            if let env = child.value as? AnyEnvironment {
                env.inject(EnvironmentStore.shared.current)
            }
        }
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
            let node = resolveTextField(textField, path: path)
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

        // NavigationStack
        if let navStack = view as? NavigationStack {
            let node = resolveNavigationStack(navStack, path: path)
            node.id = path
            return node
        }

        // Sidebar
        if let sidebar = view as? Sidebar {
            let node = resolveSidebar(sidebar, path: path)
            node.id = path
            return node
        }

        // SidebarItem
        if let item = view as? SidebarItem {
            let node = resolveSidebarItem(item)
            node.id = path
            return node
        }

        // Sheet
        if let sheet = view as? Sheet {
            let node = resolveSheet(sheet, path: path)
            node.id = path
            return node
        }

        // FlowStack
        if let flowStack = view as? FlowStack {
            let node = resolveFlowStack(flowStack, path: path)
            node.id = path
            return node
        }

        // ModifiedView
        if let resolved = resolveModifiedView(view, path: path) {
            return resolved
        }

        // TupleView (Parameter Packs)
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
        let theme = EnvironmentStore.shared.current.theme
        let node = LayoutNode()
        node.text = text.content
        node.foregroundColor = text.color ?? theme.text
        node.backgroundColor = nil
        node.accessibilityRole = .text
        node.accessibilityLabel = text.content
        return node
    }

    private static func resolveButton(_ button: Button) -> LayoutNode {
        let theme = EnvironmentStore.shared.current.theme
        let node = LayoutNode()
        node.backgroundColor = button.backgroundColor ?? theme.buttonBackground
        node.cornerRadius = 6
        node.onTap = button.action

        let textNode = LayoutNode()
        textNode.text = button.label
        textNode.foregroundColor = theme.buttonText
        textNode.padding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

        node.children = [textNode]
        node.accessibilityRole = .button
        node.accessibilityLabel = button.label
        return node
    }

    private static func resolveImage(_ image: Image) -> LayoutNode {
        let node = LayoutNode()
        node.imageSource = image.source
        node.imageOpacity = image.opacity
        if let w = image.displayWidth { node.fixedWidth = w }
        if let h = image.displayHeight { node.fixedHeight = h }
        node.accessibilityRole = .image
        node.accessibilityLabel = image.source
        return node
    }

    private static func resolveSpacer() -> LayoutNode {
        let node = LayoutNode()
        node.isFlexible = true
        return node
    }

    private static func resolveTextField(_ textField: TextField, path: String) -> LayoutNode {
        let theme = EnvironmentStore.shared.current.theme
        let node = LayoutNode()
        node.isTextField = true
        node.textFieldBinding = textField.text
        node.textFieldPlaceholder = textField.placeholder
        node.textFieldId = path
        node.backgroundColor = theme.inputBackground
        node.cornerRadius = 4
        node.padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        node.accessibilityRole = .textField
        node.accessibilityValue = textField.text.wrappedValue

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
        
        // Capture platform from environment for native scroll behavior
        let platform = EnvironmentStore.shared.current.platform
        node.platform = platform

        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.spacing = 0
        contentNode.id = "\(path).sv"
        contentNode.children = scrollView.content.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).s\(index)")
        }

        node.children = [contentNode]
        node.accessibilityRole = .scrollArea
        return node
    }

    /// Resolve a type-erased View.
    private static func resolveAnyView(_ view: any View, path: String) -> LayoutNode {
        // Inject path into @State properties and environment into @Environment properties
        let mirror = Mirror(reflecting: view)
        for child in mirror.children {
            if let state = child.value as? AnyState {
                state.setViewPath(path)
            }
            if let env = child.value as? AnyEnvironment {
                env.inject(EnvironmentStore.shared.current)
            }
        }

        func resolveImpl<V: View>(_ v: V) -> LayoutNode {
            return ViewResolver.resolve(v, path: path)
        }
        return resolveImpl(view)
    }

    // MARK: - NavigationStack

    private static func resolveNavigationStack(_ nav: NavigationStack, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .zStack

        if let currentRoute = nav.path.current, let builder = nav.destinations[currentRoute] {
            // Show the destination for the current route
            let destView = builder()
            let child = resolveAnyView(destView, path: "\(path).nav.\(currentRoute)")
            node.children = [child]
        } else {
            // Show root content
            let children = nav.rootContent.enumerated().map { index, child in
                resolveAnyView(child, path: "\(path).nav.root.\(index)")
            }
            node.children = children
        }

        return node
    }

    // MARK: - Sidebar

    private static func resolveSidebar(_ sidebar: Sidebar, path: String) -> LayoutNode {
        let theme = EnvironmentStore.shared.current.theme

        // Root is a horizontal layout
        let node = LayoutNode()
        node.stackAxis = .horizontal
        node.spacing = 0

        // Sidebar pane (fixed width)
        let sidebarNode = LayoutNode()
        sidebarNode.stackAxis = .vertical
        sidebarNode.spacing = 0
        sidebarNode.fixedWidth = sidebar.sidebarWidth
        sidebarNode.backgroundColor = theme.sidebarBackground
        sidebarNode.padding = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        sidebarNode.id = "\(path).sidebar"
        sidebarNode.children = sidebar.sidebarContent.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).sb.\(index)")
        }

        // Detail pane (fills remaining space)
        let detailNode = LayoutNode()
        detailNode.stackAxis = .vertical
        detailNode.spacing = 0
        detailNode.isFlexible = true
        detailNode.backgroundColor = theme.background
        detailNode.id = "\(path).detail"
        detailNode.children = sidebar.detailContent.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).dt.\(index)")
        }

        node.children = [sidebarNode, detailNode]
        return node
    }

    // MARK: - SidebarItem

    private static func resolveSidebarItem(_ item: SidebarItem) -> LayoutNode {
        let theme = EnvironmentStore.shared.current.theme

        let node = LayoutNode()
        node.onTap = item.action
        node.backgroundColor = item.isSelected ? theme.sidebarSelection : nil
        node.padding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        node.accessibilityRole = .button
        node.accessibilityLabel = item.label

        let textNode = LayoutNode()
        textNode.text = item.label
        textNode.foregroundColor = item.isSelected ? theme.text : theme.sidebarText
        node.children = [textNode]

        return node
    }

    // MARK: - Sheet

    private static func resolveSheet(_ sheet: Sheet, path: String) -> LayoutNode {
        // If not presented, return empty node
        guard sheet.isPresented.wrappedValue else {
            let node = LayoutNode()
            node.id = path
            return node
        }

        let theme = EnvironmentStore.shared.current.theme

        // Overlay container (ZStack-like, fills viewport)
        let node = LayoutNode()
        node.stackAxis = .zStack

        // Semi-transparent backdrop
        let backdrop = LayoutNode()
        backdrop.backgroundColor = Color(0, 0, 0, 0.5)
        backdrop.isFlexible = true
        let binding = sheet.isPresented
        backdrop.onTap = { binding.wrappedValue = false }
        backdrop.id = "\(path).backdrop"

        // Sheet content container
        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.spacing = 0
        contentNode.backgroundColor = theme.surface
        contentNode.cornerRadius = 12
        contentNode.padding = EdgeInsets(24)
        if let w = sheet.sheetWidth { contentNode.fixedWidth = w }
        if let h = sheet.sheetHeight { contentNode.fixedHeight = h }
        contentNode.id = "\(path).content"
        contentNode.accessibilityRole = .window
        contentNode.children = sheet.sheetContent.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).sc.\(index)")
        }

        node.children = [backdrop, contentNode]
        return node
    }

    // MARK: - FlowStack

    private static func resolveFlowStack(_ flowStack: FlowStack, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .horizontal
        node.flexWrap = true
        node.spacing = flowStack.spacing
        node.lineSpacing = flowStack.lineSpacing
        node.children = flowStack.resolvedChildren(path: path)
        return node
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

    // MARK: - TupleView

    private static func resolveTupleView<V: View>(_ view: V, path: String) -> LayoutNode? {
        guard let tupleView = view as? AnyTupleView else { return nil }
        
        let children = tupleView.childrenViews.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).\(index)")
        }

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

/// Type-erased protocol for EnvironmentModifier so we can detect it at runtime.
protocol AnyEnvironmentModifier {
    func applyToStore()
}

extension EnvironmentModifier: AnyEnvironmentModifier {
    func applyToStore() {
        var values = EnvironmentValues()
        values[keyPath: keyPath] = value
        EnvironmentStore.shared.push(values)
    }
}

extension ModifiedView: AnyModifiedView {
    func resolveModified(path: String) -> LayoutNode {
        // If this is an environment modifier, push a new scope before resolving content
        if let envMod = modifier as? AnyEnvironmentModifier {
            envMod.applyToStore()
            let node = ViewResolver.resolve(content, path: "\(path).m")
            EnvironmentStore.shared.pop()
            return node
        }

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
