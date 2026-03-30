import CVulkan

// MARK: - RenderCollector

/// A standalone renderable layer (e.g., a blurred sub-tree).
public struct RenderLayer: Sendable {
    public var quads: [Quad] = []
    public var textCommands: [TextDrawCommand] = []
    public var imageCommands: [ImageDrawCommand] = []
    public var blurRadius: Float = 0
    public var opacity: Float = 1.0
    // The bounds of this layer in logical pixels
    public var x: Float = 0
    public var y: Float = 0
    public var width: Float = 0
    public var height: Float = 0
}

/// Walks a resolved LayoutNode tree and produces arrays of Quads, TextDrawCommands,
/// and ImageDrawCommands ready to be rendered by the VulkanRenderer.
public struct RenderOutput: Sendable {
    public var quads: [Quad] = []
    public var textCommands: [TextDrawCommand] = []
    public var imageCommands: [ImageDrawCommand] = []
    public var layers: [RenderLayer] = []

    /// Scale all coordinates and sizes in this output by a factor (e.g., DPI scale).
    public func scaled(by factor: Float) -> RenderOutput {
        if factor == 1.0 { return self }
        var scaled = RenderOutput()
        scaled.quads = quads.map { q in
            var n = q
            n.x *= factor; n.y *= factor; n.width *= factor; n.height *= factor
            n.clipRect.x *= factor; n.clipRect.y *= factor; n.clipRect.width *= factor; n.clipRect.height *= factor
            return n
        }
        scaled.textCommands = textCommands.map { t in
            var n = t
            n.x *= factor; n.y *= factor; n.scale *= factor; n.maxWidth *= factor
            n.clipRect.x *= factor; n.clipRect.y *= factor; n.clipRect.width *= factor; n.clipRect.height *= factor
            return n
        }
        scaled.imageCommands = imageCommands.map { i in
            var n = i
            n.x *= factor; n.y *= factor; n.width *= factor; n.height *= factor
            n.clipRect.x *= factor; n.clipRect.y *= factor; n.clipRect.width *= factor; n.clipRect.height *= factor
            return n
        }
        scaled.layers = layers.map { l in
            var n = l
            n.x *= factor; n.y *= factor; n.width *= factor; n.height *= factor
            n.blurRadius *= factor
            // Inner commands within the layer should be relative to layer (0,0) or absolute?
            // For now, let's keep them absolute and scale them.
            n.quads = l.quads.map { q in
                var nq = q
                nq.x *= factor; nq.y *= factor; nq.width *= factor; nq.height *= factor
                nq.clipRect.x *= factor; nq.clipRect.y *= factor; nq.clipRect.width *= factor; nq.clipRect.height *= factor
                return nq
            }
            n.textCommands = l.textCommands.map { t in
                var nt = t
                nt.x *= factor; nt.y *= factor; nt.scale *= factor; nt.maxWidth *= factor
                nt.clipRect.x *= factor; nt.clipRect.y *= factor; nt.clipRect.width *= factor; nt.clipRect.height *= factor
                return nt
            }
            n.imageCommands = l.imageCommands.map { i in
                var ni = i
                ni.x *= factor; ni.y *= factor; ni.width *= factor; ni.height *= factor
                ni.clipRect.x *= factor; ni.clipRect.y *= factor; ni.clipRect.width *= factor; ni.clipRect.height *= factor
                return ni
            }
            return n
        }
        return scaled
    }
}

public enum RenderCollector {

    /// Collect all drawable elements from the layout tree.
    public static func collect(from root: LayoutNode) -> RenderOutput {
        var output = RenderOutput()
        collectNode(root, clip: .none, into: &output)
        return output
    }

    private static func collectNode(_ node: LayoutNode, clip: ClipRect, into output: inout RenderOutput) {
        // Skip hidden nodes entirely
        if node.isHidden { return }

        // If this node has a blur, we collect its content into a separate layer
        if node.blurRadius > 0 {
            var layer = RenderLayer()
            layer.blurRadius = node.blurRadius
            layer.opacity = node.opacity
            layer.x = node.x; layer.y = node.y
            layer.width = node.width; layer.height = node.height
            
            // Recursively collect node content and its children into the layer
            // Note: We pass a temporary RenderOutput to capture the commands
            var layerOutput = RenderOutput()
            collectNodeContent(node, clip: .none, into: &layerOutput)
            
            layer.quads = layerOutput.quads
            layer.textCommands = layerOutput.textCommands
            layer.imageCommands = layerOutput.imageCommands
            output.layers.append(layer)
            return
        }

        collectNodeContent(node, clip: clip, into: &output)
    }

    private static func collectNodeContent(_ node: LayoutNode, clip: ClipRect, into output: inout RenderOutput) {
        // Draw border if present (rendered as four thin quads)
        if let bc = node.borderColor, node.borderWidth > 0 {
            let bw = node.borderWidth
            let x = node.x, y = node.y, w = node.width, h = node.height
            // Top
            output.quads.append(Quad(x: x, y: y, width: w, height: bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a, clipRect: clip))
            // Bottom
            output.quads.append(Quad(x: x, y: y + h - bw, width: w, height: bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a, clipRect: clip))
            // Left
            output.quads.append(Quad(x: x, y: y + bw, width: bw, height: h - 2 * bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a, clipRect: clip))
            // Right
            output.quads.append(Quad(x: x + w - bw, y: y + bw, width: bw, height: h - 2 * bw, r: bc.r, g: bc.g, b: bc.b, a: bc.a, clipRect: clip))
        }

        // Draw shadow if present (rendered behind background)
        if let sc = node.shadowColor, node.shadowRadius > 0 {
            output.quads.append(Quad(
                x: node.x + node.shadowOffsetX,
                y: node.y + node.shadowOffsetY,
                width: node.width,
                height: node.height,
                r: sc.r, g: sc.g, b: sc.b, a: sc.a,
                cornerRadius: node.cornerRadius,
                shadowRadius: node.shadowRadius,
                clipRect: clip
            ))
        }

        // Draw background if present
        if let bg = node.backgroundColor {
            output.quads.append(Quad(
                x: node.x, y: node.y,
                width: node.width, height: node.height,
                r: bg.r, g: bg.g, b: bg.b, a: bg.a,
                cornerRadius: node.cornerRadius,
                clipRect: clip
            ))
        }

        // Draw image if this is an Image node
        if let source = node.imageSource {
            output.imageCommands.append(ImageDrawCommand(
                textureId: source,
                x: node.x, y: node.y,
                width: node.width, height: node.height,
                opacity: node.imageOpacity,
                clipRect: clip
            ))
        }

        // Draw text as actual text (not placeholder rects)
        if let text = node.text, !text.isEmpty {
            let fg = node.foregroundColor ?? .text
            let scale = node.fontSize / 16.0
            let availWidth = node.width - node.padding.leading - node.padding.trailing
            let maxTextWidth = node.maxTextWidth ?? (availWidth > 0 ? availWidth : 0)
            let textSize = FontManager.shared.measureText(text, fontSize: node.fontSize)
            let textWidth = textSize.width
            let textHeight = textSize.height

            let textX = node.x + node.padding.leading
            let textY = node.y + node.padding.top + max(0, (node.height - node.padding.top - node.padding.bottom - textHeight) / 2)

            output.textCommands.append(TextDrawCommand(
                text: text,
                x: textX, y: textY,
                scale: scale,
                r: fg.r, g: fg.g, b: fg.b, a: fg.a,
                maxWidth: maxTextWidth,
                clipRect: clip
            ))
        }

        // Determine clip rect for children: if this is a ScrollView, clip to its bounds
        var childClip = clip
        if node.isScrollView {
            let scrollClip = ClipRect(x: node.x, y: node.y, width: node.width, height: node.height)
            childClip = clip.isNone ? scrollClip : clip.intersected(with: scrollClip)
        }

        // Recurse into children
        for child in node.children {
            collectNode(child, clip: childClip, into: &output)
        }
    }
}
