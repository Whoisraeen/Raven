import CVulkan

// MARK: - RenderCollector

/// Walks a resolved LayoutNode tree and produces arrays of Quads, TextDrawCommands,
/// and ImageDrawCommands ready to be rendered by the VulkanRenderer.
public struct RenderOutput {
    public var quads: [Quad] = []
    public var textCommands: [TextDrawCommand] = []
    public var imageCommands: [ImageDrawCommand] = []
}

public enum RenderCollector {

    /// Collect all drawable elements from the layout tree.
    public static func collect(from root: LayoutNode) -> RenderOutput {
        var output = RenderOutput()
        collectNode(root, into: &output)
        return output
    }

    private static func collectNode(_ node: LayoutNode, into output: inout RenderOutput) {
        // Draw background if present
        if let bg = node.backgroundColor {
            output.quads.append(Quad(
                x: node.x, y: node.y,
                width: node.width, height: node.height,
                r: bg.r, g: bg.g, b: bg.b, a: bg.a
            ))
        }

        // Draw image if this is an Image node
        if let source = node.imageSource {
            output.imageCommands.append(ImageDrawCommand(
                textureId: source,
                x: node.x, y: node.y,
                width: node.width, height: node.height,
                opacity: node.imageOpacity
            ))
        }

        // Draw text as actual text (not placeholder rects)
        if let text = node.text, !text.isEmpty {
            let fg = node.foregroundColor ?? .text
            // Center text within the node using exact measurement
            let textSize = FontManager.shared.measureText(text, fontSize: 16.0)
            let textWidth = textSize.width
            let textHeight = textSize.height
            
            // TextRenderer expects x, y to be the top-left of the bounding box.
            let textX = node.x + node.padding.leading + max(0, (node.width - node.padding.leading - node.padding.trailing - textWidth) / 2)
            let textY = node.y + node.padding.top + max(0, (node.height - node.padding.top - node.padding.bottom - textHeight) / 2)

            output.textCommands.append(TextDrawCommand(
                text: text,
                x: textX, y: textY,
                scale: 1.0, // Scale 1.0 means 16.0 base size
                r: fg.r, g: fg.g, b: fg.b, a: fg.a
            ))
        }

        // Recurse into children
        for child in node.children {
            collectNode(child, into: &output)
        }
    }
}
