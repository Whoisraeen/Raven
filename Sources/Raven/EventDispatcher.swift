import CSDL3

// MARK: - EventDispatcher

/// Dispatches SDL input events to the view tree.
/// Performs hit testing on LayoutNodes to determine which view
/// received a click, hover, etc.
public class EventDispatcher {

    /// The currently dragged slider node (if any).
    /// Set on mouse down over a slider, cleared on mouse up.
    public static var activeSliderNode: LayoutNode? = nil

    /// The currently expanded menu picker node (if any).
    /// Tracked so we can close it when clicking elsewhere.
    public static var expandedMenuPickerNode: LayoutNode? = nil

    /// Process a mouse click at the given coordinates.
    /// Walks the LayoutNode tree, finds the deepest node at (x,y),
    /// and fires its action if it has one. Also manages TextField focus.
    public static func handleClick(x: Float, y: Float, root: LayoutNode) {
        guard let hitNode = hitTest(x: x, y: y, node: root) else {
            // Clicked outside all nodes — clear focus and close dropdowns
            FocusManager.shared.clearFocus()
            closeExpandedPicker()
            return
        }

        // Toggle: flip the boolean binding
        if hitNode.isToggle, let binding = hitNode.toggleBinding {
            binding.wrappedValue.toggle()
            return
        }

        // Also check if we hit a node whose parent is a toggle
        if let toggleNode = findAncestorToggle(of: hitNode, in: root) {
            if let binding = toggleNode.toggleBinding {
                binding.wrappedValue.toggle()
                return
            }
        }

        // Picker segment: update selection index
        if hitNode.isPicker, hitNode.pickerSegmentIndex >= 0,
           let binding = hitNode.pickerBinding {
            binding.wrappedValue = hitNode.pickerSegmentIndex
            closeExpandedPicker()
            return
        }

        // Picker trigger (menu style): toggle dropdown expansion
        if hitNode.isPicker, hitNode.pickerSegmentIndex == -1 {
            // Find the parent picker node to toggle its expanded state
            if let pickerRoot = findAncestorMenuPicker(of: hitNode, in: root) {
                pickerRoot.isPickerExpanded.toggle()
                if pickerRoot.isPickerExpanded {
                    expandedMenuPickerNode = pickerRoot
                } else {
                    expandedMenuPickerNode = nil
                }
                StateTracker.shared.markDirty()
                return
            }
        }

        // Slider: start drag
        if hitNode.isSlider {
            activeSliderNode = hitNode
            handleSliderDrag(x: x, sliderNode: hitNode)
            return
        }

        // Also check if we hit a child of a slider
        if let sliderNode = findAncestorSlider(of: hitNode, in: root) {
            activeSliderNode = sliderNode
            handleSliderDrag(x: x, sliderNode: sliderNode)
            return
        }

        // If the hit node is a text field, set focus to it
        if hitNode.isTextField,
           let fieldId = hitNode.textFieldId,
           let binding = hitNode.textFieldBinding {
            FocusManager.shared.setFocus(fieldId: fieldId, binding: binding)
            closeExpandedPicker()
            return
        }

        // If the hit node has a tap action (e.g., Button), fire it
        if let action = hitNode.onTap {
            action()
        }

        // Clicking on a non-TextField clears focus
        if !hitNode.isTextField {
            FocusManager.shared.clearFocus()
        }

        // Close expanded picker when clicking elsewhere
        closeExpandedPicker()
    }

    /// Handle mouse motion during slider drag.
    public static func handleMouseMotion(x: Float, y: Float) {
        guard let sliderNode = activeSliderNode else { return }
        handleSliderDrag(x: x, sliderNode: sliderNode)
    }

    /// Handle mouse button release.
    public static func handleMouseUp() {
        activeSliderNode = nil
    }

    /// Recursive hit test — returns the deepest node containing (x, y).
    /// Children are tested in reverse order (front-to-back visually).
    /// Skips hidden and disabled nodes.
    public static func hitTest(x: Float, y: Float, node: LayoutNode) -> LayoutNode? {
        // Skip hidden or disabled nodes entirely
        if node.isHidden || node.isDisabled { return nil }

        // Check children first (front-to-back, last child is on top)
        for child in node.children.reversed() {
            if let hit = hitTest(x: x, y: y, node: child) {
                return hit
            }
        }

        // Check this node
        if x >= node.x && x <= node.x + node.width &&
           y >= node.y && y <= node.y + node.height {
            return node
        }

        return nil
    }

    // MARK: - Slider Drag Logic

    private static func handleSliderDrag(x: Float, sliderNode: LayoutNode) {
        guard let binding = sliderNode.sliderBinding else { return }
        let range = sliderNode.sliderRange
        let trackWidth = sliderNode.width

        guard trackWidth > 0 else { return }

        // Compute normalized position within the slider track
        let relativeX = x - sliderNode.x
        let normalizedX = min(max(relativeX / trackWidth, 0), 1)

        // Map to value range
        var newValue = range.lowerBound + normalizedX * (range.upperBound - range.lowerBound)

        // Snap to step if specified
        if let step = sliderNode.sliderStep, step > 0 {
            newValue = (newValue / step).rounded() * step
        }

        // Clamp to range
        newValue = min(max(newValue, range.lowerBound), range.upperBound)

        binding.wrappedValue = newValue
    }

    // MARK: - Ancestor Search Helpers

    /// Walk up (via tree search) to find a Toggle ancestor of the hit node.
    private static func findAncestorToggle(of target: LayoutNode, in root: LayoutNode) -> LayoutNode? {
        if root.isToggle && containsNode(target, in: root) {
            return root
        }
        for child in root.children {
            if let found = findAncestorToggle(of: target, in: child) {
                return found
            }
        }
        return nil
    }

    /// Walk up to find a Slider ancestor.
    private static func findAncestorSlider(of target: LayoutNode, in root: LayoutNode) -> LayoutNode? {
        if root.isSlider && containsNode(target, in: root) {
            return root
        }
        for child in root.children {
            if let found = findAncestorSlider(of: target, in: child) {
                return found
            }
        }
        return nil
    }

    /// Walk up to find a menu-style Picker ancestor.
    private static func findAncestorMenuPicker(of target: LayoutNode, in root: LayoutNode) -> LayoutNode? {
        if root.isPicker && root.pickerStyle == .menu && containsNode(target, in: root) {
            return root
        }
        for child in root.children {
            if let found = findAncestorMenuPicker(of: target, in: child) {
                return found
            }
        }
        return nil
    }

    /// Check if `target` is the same object as or a descendant of `parent`.
    private static func containsNode(_ target: LayoutNode, in parent: LayoutNode) -> Bool {
        if target === parent { return true }
        for child in parent.children {
            if containsNode(target, in: child) { return true }
        }
        return false
    }

    /// Close any expanded menu picker.
    private static func closeExpandedPicker() {
        if let picker = expandedMenuPickerNode {
            picker.isPickerExpanded = false
            expandedMenuPickerNode = nil
            StateTracker.shared.markDirty()
        }
    }
}
