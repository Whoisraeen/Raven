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

        // Toggle
        if let toggle = view as? Toggle {
            let node = resolveToggle(toggle, path: path)
            node.id = path
            return node
        }

        // Slider
        if let slider = view as? Slider {
            let node = resolveSlider(slider, path: path)
            node.id = path
            return node
        }

        // Picker
        if let picker = view as? Picker {
            let node = resolvePicker(picker, path: path)
            node.id = path
            return node
        }

        // ProgressView
        if let progressView = view as? ProgressView {
            let node = resolveProgressView(progressView, path: path)
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

        // TabView
        if let tabView = view as? TabView {
            let node = resolveTabView(tabView, path: path)
            node.id = path
            return node
        }

        // NavigationView
        if let navView = view as? NavigationView {
            let node = resolveNavigationView(navView, path: path)
            node.id = path
            return node
        }

        // Divider
        if view is Divider {
            let node = resolveDivider()
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
        let theme = Theme.current
        let node = LayoutNode()
        node.text = text.content
        node.foregroundColor = text.color ?? theme.colors.text
        node.backgroundColor = nil
        node.accessibilityRole = .text
        node.accessibilityLabel = text.content
        return node
    }

    private static func resolveButton(_ button: Button) -> LayoutNode {
        let theme = Theme.current
        let node = LayoutNode()
        node.backgroundColor = button.backgroundColor ?? theme.colors.primary
        node.cornerRadius = theme.shapes.md
        node.onTap = button.action

        let textNode = LayoutNode()
        textNode.text = button.label
        textNode.foregroundColor = .buttonText
        textNode.padding = EdgeInsets(
            top: theme.spacing.sm,
            leading: theme.spacing.lg,
            bottom: theme.spacing.sm,
            trailing: theme.spacing.lg
        )
        
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
        let theme = Theme.current
        let node = LayoutNode()
        node.isTextField = true
        node.textFieldBinding = textField.text
        node.textFieldPlaceholder = textField.placeholder
        node.textFieldId = path
        node.backgroundColor = theme.colors.surface
        node.cornerRadius = theme.shapes.sm
        node.padding = EdgeInsets(
            top: theme.spacing.sm,
            leading: theme.spacing.md,
            bottom: theme.spacing.sm,
            trailing: theme.spacing.md
        )
        node.accessibilityRole = .textField
        node.accessibilityValue = textField.text.wrappedValue

        if node.fixedWidth == nil { node.fixedWidth = 200 }
        return node
    }

    // MARK: - Toggle

    private static func resolveToggle(_ toggle: Toggle, path: String) -> LayoutNode {
        let theme = Theme.current
        let node = LayoutNode()
        node.stackAxis = .horizontal
        node.spacing = theme.spacing.md
        node.verticalAlignment = .center
        node.isToggle = true
        node.toggleBinding = toggle.isOn
        node.accessibilityRole = .toggle
        node.accessibilityLabel = toggle.label
        node.accessibilityValue = toggle.isOn.wrappedValue ? "on" : "off"

        // Label text
        if !toggle.label.isEmpty {
            let labelNode = LayoutNode()
            labelNode.text = toggle.label
            labelNode.foregroundColor = .text
            labelNode.id = "\(path).tl"
            node.children.append(labelNode)
        }

        // Track (the pill-shaped background)
        let isOn = toggle.isOn.wrappedValue
        let trackNode = LayoutNode()
        trackNode.fixedWidth = 44
        trackNode.fixedHeight = 24
        trackNode.cornerRadius = 12
        trackNode.backgroundColor = isOn ? .primary : .trackBackground
        trackNode.id = "\(path).tt"

        // Thumb (the circle that slides)
        let thumbNode = LayoutNode()
        thumbNode.fixedWidth = 18
        thumbNode.fixedHeight = 18
        thumbNode.cornerRadius = 9
        thumbNode.backgroundColor = .thumbColor
        // Position thumb: left (off) or right (on)
        thumbNode.padding = EdgeInsets(
            top: 3,
            leading: isOn ? 23 : 3,
            bottom: 3,
            trailing: isOn ? 3 : 23
        )
        thumbNode.id = "\(path).th"

        trackNode.children = [thumbNode]
        node.children.append(trackNode)

        return node
    }

    // MARK: - Slider

    private static func resolveSlider(_ slider: Slider, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.isSlider = true
        node.sliderBinding = slider.value
        node.sliderRange = slider.range
        node.sliderStep = slider.step
        node.fixedWidth = 200
        node.fixedHeight = 24
        node.accessibilityRole = .slider
        let pct = (slider.value.wrappedValue - slider.range.lowerBound) / (slider.range.upperBound - slider.range.lowerBound)
        node.accessibilityValue = String(format: "%.0f%%", pct * 100)

        // Track background (full width, 4px tall, centered)
        let trackNode = LayoutNode()
        trackNode.fixedWidth = 200
        trackNode.fixedHeight = 4
        trackNode.cornerRadius = 2
        trackNode.backgroundColor = .trackBackground
        trackNode.padding = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        trackNode.id = "\(path).st"

        // Filled portion of the track
        let clampedPct = min(max(pct, 0), 1)
        let filledWidth = 200 * clampedPct
        let filledNode = LayoutNode()
        filledNode.fixedWidth = filledWidth
        filledNode.fixedHeight = 4
        filledNode.cornerRadius = 2
        filledNode.backgroundColor = .primary
        filledNode.padding = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        filledNode.id = "\(path).sf"

        // Thumb
        let thumbNode = LayoutNode()
        thumbNode.fixedWidth = 16
        thumbNode.fixedHeight = 16
        thumbNode.cornerRadius = 8
        thumbNode.backgroundColor = .thumbColor
        thumbNode.id = "\(path).sh"

        node.children = [trackNode, filledNode, thumbNode]
        return node
    }

    // MARK: - Picker

    private static func resolvePicker(_ picker: Picker, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.isPicker = true
        node.pickerBinding = picker.selection
        node.pickerOptions = picker.options
        node.pickerStyle = picker.style
        node.accessibilityRole = .picker
        node.accessibilityLabel = picker.label
        if picker.selection.wrappedValue >= 0 && picker.selection.wrappedValue < picker.options.count {
            node.accessibilityValue = picker.options[picker.selection.wrappedValue]
        }

        switch picker.style {
        case .segmented:
            return resolveSegmentedPicker(picker, node: node, path: path)
        case .menu:
            return resolveMenuPicker(picker, node: node, path: path)
        }
    }

    private static func resolveSegmentedPicker(_ picker: Picker, node: LayoutNode, path: String) -> LayoutNode {
        // Horizontal container with segment buttons
        node.stackAxis = .horizontal
        node.spacing = 0
        node.backgroundColor = .trackBackground
        node.cornerRadius = 8
        node.padding = EdgeInsets(2)

        // Optional label above the control
        var container = node
        if !picker.label.isEmpty {
            let wrapper = LayoutNode()
            wrapper.stackAxis = .vertical
            wrapper.spacing = 6
            wrapper.id = "\(path).pw"

            let labelNode = LayoutNode()
            labelNode.text = picker.label
            labelNode.foregroundColor = .textSecondary
            labelNode.id = "\(path).pl"

            wrapper.children = [labelNode, node]
            container = wrapper
        }

        for (index, option) in picker.options.enumerated() {
            let isSelected = index == picker.selection.wrappedValue

            let segmentNode = LayoutNode()
            segmentNode.isPicker = true
            segmentNode.pickerBinding = picker.selection
            segmentNode.pickerSegmentIndex = index
            segmentNode.pickerOptions = picker.options
            segmentNode.backgroundColor = isSelected ? .primary : .clear
            segmentNode.cornerRadius = 6
            segmentNode.id = "\(path).ps\(index)"

            let textNode = LayoutNode()
            textNode.text = option
            textNode.foregroundColor = isSelected ? .buttonText : .text
            textNode.padding = EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            textNode.id = "\(path).pst\(index)"

            segmentNode.children = [textNode]
            node.children.append(segmentNode)
        }

        return container
    }

    private static func resolveMenuPicker(_ picker: Picker, node: LayoutNode, path: String) -> LayoutNode {
        // Vertical container: trigger button + dropdown list
        node.stackAxis = .vertical
        node.spacing = 0

        // Determine the currently selected text
        let selectedIndex = picker.selection.wrappedValue
        let selectedText = (selectedIndex >= 0 && selectedIndex < picker.options.count)
            ? picker.options[selectedIndex] : "Select..."

        // Trigger button (shows current selection + dropdown indicator)
        let triggerNode = LayoutNode()
        triggerNode.isPicker = true
        triggerNode.pickerBinding = picker.selection
        triggerNode.pickerOptions = picker.options
        triggerNode.pickerSegmentIndex = -1  // Marks this as the trigger
        triggerNode.isPickerExpanded = false
        triggerNode.backgroundColor = .surface
        triggerNode.cornerRadius = 6
        triggerNode.id = "\(path).pt"

        let triggerContent = LayoutNode()
        triggerContent.stackAxis = .horizontal
        triggerContent.spacing = 8
        triggerContent.id = "\(path).ptc"

        // Label (optional)
        if !picker.label.isEmpty {
            let labelNode = LayoutNode()
            labelNode.text = picker.label
            labelNode.foregroundColor = .textSecondary
            labelNode.padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 0)
            labelNode.id = "\(path).ptl"
            triggerContent.children.append(labelNode)
        }

        let valueNode = LayoutNode()
        valueNode.text = selectedText
        valueNode.foregroundColor = .text
        valueNode.padding = EdgeInsets(top: 8, leading: picker.label.isEmpty ? 12 : 4, bottom: 8, trailing: 4)
        valueNode.id = "\(path).ptv"

        let arrowNode = LayoutNode()
        arrowNode.text = "▾"
        arrowNode.foregroundColor = .textSecondary
        arrowNode.padding = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 12)
        arrowNode.id = "\(path).pta"

        triggerContent.children.append(valueNode)
        triggerContent.children.append(arrowNode)
        triggerNode.children = [triggerContent]
        node.children.append(triggerNode)

        // Dropdown list (only visible when expanded)
        // The expanded state is managed by the EventDispatcher;
        // we always emit the option nodes but they are hidden unless expanded.
        // For now, we use the picker node's isPickerExpanded property.
        // The rendering will be controlled by checking this flag.
        if node.isPickerExpanded {
            let dropdownNode = LayoutNode()
            dropdownNode.stackAxis = .vertical
            dropdownNode.spacing = 0
            dropdownNode.backgroundColor = .surface
            dropdownNode.cornerRadius = 6
            dropdownNode.padding = EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
            dropdownNode.id = "\(path).pd"

            for (index, option) in picker.options.enumerated() {
                let isSelected = index == selectedIndex
                let optionNode = LayoutNode()
                optionNode.isPicker = true
                optionNode.pickerBinding = picker.selection
                optionNode.pickerSegmentIndex = index
                optionNode.pickerOptions = picker.options
                optionNode.backgroundColor = isSelected ? .primary : .clear
                optionNode.id = "\(path).po\(index)"

                let optionText = LayoutNode()
                optionText.text = option
                optionText.foregroundColor = isSelected ? .buttonText : .text
                optionText.padding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
                optionText.id = "\(path).pot\(index)"

                optionNode.children = [optionText]
                dropdownNode.children.append(optionNode)
            }

            node.children.append(dropdownNode)
        }

        return node
    }

    // MARK: - ProgressView

    private static func resolveProgressView(_ progressView: ProgressView, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.isProgressView = true
        node.progressValue = progressView.value
        node.progressTotal = progressView.total
        node.stackAxis = .vertical
        node.spacing = 4
        node.accessibilityRole = .progressBar
        if let val = progressView.value {
            let pct = min(val / progressView.total, 1.0) * 100
            node.accessibilityValue = String(format: "%.0f%%", pct)
        } else {
            node.accessibilityValue = "indeterminate"
        }

        // Label (if provided)
        if !progressView.label.isEmpty {
            let labelNode = LayoutNode()
            labelNode.text = progressView.label
            labelNode.foregroundColor = .textSecondary
            labelNode.id = "\(path).pvl"
            node.children.append(labelNode)
        }

        // Track background
        let trackNode = LayoutNode()
        trackNode.fixedWidth = 200
        trackNode.fixedHeight = 6
        trackNode.cornerRadius = 3
        trackNode.backgroundColor = .trackBackground
        trackNode.id = "\(path).pvt"

        // Filled bar
        if let val = progressView.value {
            let pct = min(max(val / progressView.total, 0), 1)
            let filledNode = LayoutNode()
            filledNode.fixedWidth = 200 * pct
            filledNode.fixedHeight = 6
            filledNode.cornerRadius = 3
            filledNode.backgroundColor = .primary
            filledNode.id = "\(path).pvf"
            trackNode.children = [filledNode]
        }

        node.children.append(trackNode)

        // Percentage text
        if let val = progressView.value {
            let pct = min(val / progressView.total, 1.0) * 100
            let pctNode = LayoutNode()
            pctNode.text = String(format: "%.0f%%", pct)
            pctNode.foregroundColor = .textSecondary
            pctNode.id = "\(path).pvp"
            node.children.append(pctNode)
        }

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

    // MARK: - TabView

    private static func resolveTabView(_ tabView: TabView, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.tabSelection = tabView.selection
        node.tabLabels = tabView.tabs.map { $0.label }

        // Content area — show the selected tab's content
        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.id = "\(path).tc"

        let selectedIndex = tabView.selection.wrappedValue
        if selectedIndex >= 0 && selectedIndex < tabView.tabs.count {
            let tab = tabView.tabs[selectedIndex]
            contentNode.children = tab.content.enumerated().map { index, child in
                resolveAnyView(child, path: "\(path).t\(selectedIndex).\(index)")
            }
        }

        // Tab bar at the bottom
        let tabBarNode = LayoutNode()
        tabBarNode.stackAxis = .horizontal
        tabBarNode.spacing = 0
        tabBarNode.backgroundColor = Theme.current.colors.surface
        tabBarNode.id = "\(path).tb"

        for (index, tab) in tabView.tabs.enumerated() {
            let tabNode = LayoutNode()
            tabNode.text = tab.label
            tabNode.foregroundColor = index == selectedIndex
                ? Theme.current.colors.primary
                : Theme.current.colors.textSecondary
            tabNode.padding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            tabNode.id = "\(path).tb\(index)"
            tabNode.isFlexible = true  // flex equally
            tabNode.onTap = { [selection = tabView.selection, idx = index] in
                selection.wrappedValue = idx
            }
            tabBarNode.children.append(tabNode)
        }

        // Divider above tab bar
        let dividerNode = LayoutNode()
        dividerNode.isDivider = true
        dividerNode.fixedHeight = 1
        dividerNode.backgroundColor = Theme.current.colors.divider
        dividerNode.id = "\(path).td"

        // Content takes up remaining space
        let spacerNode = LayoutNode()
        spacerNode.isFlexible = true
        spacerNode.id = "\(path).ts"

        node.children = [contentNode, spacerNode, dividerNode, tabBarNode]
        node.accessibilityRole = .none
        return node
    }

    // MARK: - NavigationView

    private static func resolveNavigationView(_ navView: NavigationView, path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.navigationTitle = navView.title

        // Navigation bar
        let navBar = LayoutNode()
        navBar.stackAxis = .horizontal
        navBar.backgroundColor = Theme.current.colors.surface
        navBar.padding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        navBar.id = "\(path).nb"

        let titleNode = LayoutNode()
        titleNode.text = navView.title
        titleNode.foregroundColor = Theme.current.colors.text
        titleNode.id = "\(path).nt"
        navBar.children = [titleNode]

        // Divider
        let dividerNode = LayoutNode()
        dividerNode.isDivider = true
        dividerNode.fixedHeight = 1
        dividerNode.backgroundColor = Theme.current.colors.divider
        dividerNode.id = "\(path).nd"

        // Content
        let contentNode = LayoutNode()
        contentNode.stackAxis = .vertical
        contentNode.id = "\(path).nc"
        contentNode.children = navView.content.enumerated().map { index, child in
            resolveAnyView(child, path: "\(path).n\(index)")
        }

        node.children = [navBar, dividerNode, contentNode]
        return node
    }

    // MARK: - Divider

    private static func resolveDivider() -> LayoutNode {
        let node = LayoutNode()
        node.isDivider = true
        node.fixedHeight = 1
        node.backgroundColor = Theme.current.colors.divider
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
