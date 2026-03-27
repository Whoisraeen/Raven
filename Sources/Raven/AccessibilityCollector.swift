// MARK: - AccessibilityCollector

/// Represents an element in the resolved accessibility tree.
public struct AccessibilityElement: CustomStringConvertible, Sendable {
    public let role: AccessibilityRole
    public let label: String?
    public let value: String?
    public let frame: (x: Float, y: Float, width: Float, height: Float)
    public let children: [AccessibilityElement]

    public var description: String {
        let attrs = [
            label.map { "label: \"\($0)\"" },
            value.map { "value: \"\($0)\"" }
        ].compactMap { $0 }.joined(separator: ", ")

        var out = "[\(role.rawValue)] \(attrs) (frame: \(frame.x), \(frame.y), \(frame.width), \(frame.height))"
        if !children.isEmpty {
            out += " {\n"
            for child in children {
                out += child.description.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n") + "\n"
            }
            out += "}"
        }
        return out
    }
}

/// Walks the LayoutNode tree and generates an OS-agnostic accessibility representation.
public enum AccessibilityCollector {
    
    /// Collect the accessibility tree starting from a root layout node.
    public static func collect(root: LayoutNode) -> AccessibilityElement? {
        return collectNode(root)
    }

    private static func collectNode(_ node: LayoutNode) -> AccessibilityElement? {
        if node.isAccessibilityHidden {
            return nil
        }

        var childElements: [AccessibilityElement] = []
        for child in node.children {
            if let el = collectNode(child) {
                childElements.append(el)
            }
        }

        // If this node has no semantic meaning and no children, ignore it
        if node.accessibilityRole == .none && childElements.isEmpty {
            return nil
        }

        // If it's just a layout container (.none) but has children, we can either
        // return a group or just bubble up the children. For now, bubble up unless it's explicitly a group.
        if node.accessibilityRole == .none {
            if childElements.count == 1 {
                return childElements[0]
            } else if childElements.count > 1 {
                // Wrap in a group
                return AccessibilityElement(
                    role: .group,
                    label: node.accessibilityLabel,
                    value: node.accessibilityValue,
                    frame: (node.x, node.y, node.width, node.height),
                    children: childElements
                )
            }
        }

        return AccessibilityElement(
            role: node.accessibilityRole,
            label: node.accessibilityLabel,
            value: node.accessibilityValue,
            frame: (node.x, node.y, node.width, node.height),
            children: childElements
        )
    }
}
