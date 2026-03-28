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
        // Skip hidden nodes entirely
        if node.isHidden { return }

        // Draw border if present (rendered as four thin quads)
        if let bc = node.borderColor, node.borderWidth > 0 {
            let bw = node.borderWidth
            let x = node.x, y = node.y, w = node.width, h = node.height
            // Top
            output.quads.append(Quad(x: x, y: y, width: w, height: bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a))
            // Bottom
            output.quads.append(Quad(x: x, y: y + h - bw, width: w, height: bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a))
            // Left
            output.quads.append(Quad(x: x, y: y + bw, width: bw, height: h - 2 * bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a))
            // Right
            output.quads.append(Quad(x: x + w - bw, y: y + bw, width: bw, height: h - 2 * bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a))
        }

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
            let scale = node.fontSize / 16.0
            let textSize = FontManager.shared.measureText(text, fontSize: node.fontSize)
            let textWidth = textSize.width
            let textHeight = textSize.height

            let textX = node.x + node.padding.leading + max(0, (node.width - node.padding.leading - node.padding.trailing - textWidth) / 2)
            let textY = node.y + node.padding.top + max(0, (node.height - node.padding.top - node.padding.bottom - textHeight) / 2)

            output.textCommands.append(TextDrawCommand(
                text: text,
                x: textX, y: textY,
                scale: scale,
                r: fg.r, g: fg.g, b: fg.b, a: fg.a
            ))
        }

        // Recurse into children
        for child in node.children {
            collectNode(child, into: &output)
        }
    }
}
