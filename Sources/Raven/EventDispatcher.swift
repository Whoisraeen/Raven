import CSDL3

// MARK: - EventDispatcher

/// Dispatches SDL input events to the view tree.
/// Performs hit testing on LayoutNodes to determine which view
/// received a click, hover, etc.
public class EventDispatcher {

    /// Process a mouse click at the given coordinates.
    /// Walks the LayoutNode tree, finds the deepest node at (x,y),
    /// and fires its action if it has one. Also manages TextField focus.
    public static func handleClick(x: Float, y: Float, root: LayoutNode) {
        guard let hitNode = hitTest(x: x, y: y, node: root) else {
            // Clicked outside all nodes — clear focus
            FocusManager.shared.clearFocus()
            return
        }

        // If the hit node is a text field, set focus to it
        if hitNode.isTextField,
           let fieldId = hitNode.textFieldId,
           let binding = hitNode.textFieldBinding {
            FocusManager.shared.setFocus(fieldId: fieldId, binding: binding)
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
}
