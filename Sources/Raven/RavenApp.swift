import CSDL3
import CVulkan


// MARK: - RavenApp

/// The main entry point for a Raven application.
/// Ties together SDL window creation, the Vulkan renderer,
/// the layout engine, and the render collector.
public class RavenApp<Content: View>: @unchecked Sendable {
    private let title: String
    private let width: Int
    private let height: Int
    private let contentBuilder: @Sendable () -> Content

    public init(
        title: String = "Raven App",
        width: Int = 960,
        height: Int = 640,
        @ViewBuilder content: @escaping @Sendable () -> Content
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.contentBuilder = content
    }

    /// Start the application event loop.
    public func run() {
        // Initialize Rust core
        RavenCore.initialize()
        print("Raven Core v\(RavenCore.version) on \(RavenCore.platformName) (\(RavenCore.osVersion))")

        // SDL Init
        guard SDL_Init(SDL_INIT_VIDEO) else {
            fail("SDL_Init failed: \(currentSDLError())")
        }
        defer { SDL_Quit() }

        let windowFlags = sdlWindowResizableFlag | sdlWindowVulkanFlag

        guard let window = SDL_CreateWindow(title, Int32(width), Int32(height), windowFlags) else {
            fail("SDL_CreateWindow failed: \(currentSDLError())")
        }
        defer { SDL_DestroyWindow(window) }

        // Create renderer
        let renderer = VulkanRenderer(window: window)
        defer { renderer.destroy() }

        // Event types
        let quitEventType = UInt32(SDL_EVENT_QUIT.rawValue)
        let keyDownEventType = UInt32(SDL_EVENT_KEY_DOWN.rawValue)
        let mouseButtonDownType = UInt32(SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue)
        let textInputEventType = UInt32(SDL_EVENT_TEXT_INPUT.rawValue)

        // Keyboard scancodes
        let scancodeEsc = SDL_Scancode(rawValue: 41)
        let scancodeBackspace = SDL_Scancode(rawValue: 42)
        let scancodeDelete = SDL_Scancode(rawValue: 76)
        let scancodeLeft = SDL_Scancode(rawValue: 80)
        let scancodeRight = SDL_Scancode(rawValue: 79)
        let scancodeHome = SDL_Scancode(rawValue: 74)
        let scancodeEnd = SDL_Scancode(rawValue: 77)

        print("Raven — \(title)")
        print("Press ESC or close the window to exit.")

        var event = SDL_Event()
        var isRunning = true

        // Keep the last layout tree for hit testing
        var rootNode: LayoutNode? = nil

        // Cached render output — reused across frames when state hasn't changed
        var cachedQuads: [Quad] = []
        var cachedTextCommands: [TextDrawCommand] = []
        var cachedImageCommands: [ImageDrawCommand] = []

        // First frame always needs a full build
        var needsRebuild = true

        while isRunning {
            while SDL_PollEvent(&event) {
                switch event.type {
                case quitEventType:
                    isRunning = false

                case keyDownEventType:
                    let scancode = event.key.scancode
                    if scancode == scancodeEsc {
                        isRunning = false
                    } else if FocusManager.shared.focusedFieldId != nil {
                        // Keyboard navigation for focused text field
                        switch scancode {
                        case scancodeBackspace: FocusManager.shared.handleBackspace()
                        case scancodeDelete:    FocusManager.shared.handleDelete()
                        case scancodeLeft:      FocusManager.shared.moveCursorLeft()
                        case scancodeRight:     FocusManager.shared.moveCursorRight()
                        case scancodeHome:      FocusManager.shared.moveCursorHome()
                        case scancodeEnd:       FocusManager.shared.moveCursorEnd()
                        default: break
                        }
                    }

                case textInputEventType:
                    // SDL_EVENT_TEXT_INPUT — route to focused text field
                    let textBuf = withUnsafePointer(to: event.text.text) { ptr in
                        String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                    }
                    FocusManager.shared.handleTextInput(textBuf)

                case mouseButtonDownType:
                    // Left mouse button click
                    let mouseX = Float(event.button.x)
                    let mouseY = Float(event.button.y)
                    if let root = rootNode {
                        EventDispatcher.handleClick(x: mouseX, y: mouseY, root: root)
                    }

                case UInt32(SDL_EVENT_MOUSE_WHEEL.rawValue):
                    // Mouse wheel — scroll the nearest ScrollView under cursor
                    let scrollAmount = Float(event.wheel.y) * -30.0  // negative = scroll down
                    if let root = rootNode {
                        // Find the scroll container under the mouse
                        if let scrollNode = findScrollNode(x: Float(event.wheel.mouse_x),
                                                           y: Float(event.wheel.mouse_y),
                                                           in: root) {
                            scrollNode.scrollStateVar?.value += scrollAmount
                        }
                    }

                default:
                    break
                }
            }

            // Check if any @State/@Published/StateVar changed
            if StateTracker.shared.checkAndClear() {
                needsRebuild = true
            }

            if isRunning {
                if needsRebuild {
                    // Re-build view tree (captures current state values)
                    let content = contentBuilder()
                    let resolved = ViewResolver.resolve(content)

                    let viewportWidth = Float(renderer.swapchainExtent.width)
                    let viewportHeight = Float(renderer.swapchainExtent.height)

                    LayoutEngine.resolve(
                        root: resolved,
                        viewportWidth: viewportWidth,
                        viewportHeight: viewportHeight
                    )

                    // Store for hit testing
                    rootNode = resolved

                    // Verify accessibility tree
                    if let a11yTree = AccessibilityCollector.collect(root: resolved) {
                        print("\n--- Accessibility Tree Rebuilt ---")
                        print(a11yTree)
                        print("----------------------------------\n")
                    }

                    // Collect quads, text commands, and image commands
                    let renderOutput = RenderCollector.collect(from: resolved)
                    cachedQuads = renderOutput.quads
                    cachedTextCommands = renderOutput.textCommands
                    cachedImageCommands = renderOutput.imageCommands

                    // Preload any new image textures
                    for imgCmd in cachedImageCommands {
                        renderer.imageRenderer.loadImage(path: imgCmd.textureId)
                    }

                    // Update font atlas texture if needed
                    renderer.textRenderer.updateAtlasIfNeeded()

                    needsRebuild = false
                }

                // Always present a frame (Vulkan swapchain expects continuous presentation)
                renderer.drawFrame(quads: cachedQuads,
                                   textCommands: cachedTextCommands,
                                   imageCommands: cachedImageCommands)
            }
        }

        print("Raven exited cleanly.")
    }
}

// MARK: - Helpers

/// Find the deepest ScrollView node that contains the given point.
private func findScrollNode(x: Float, y: Float, in node: LayoutNode) -> LayoutNode? {
    // Check children first (deeper nodes have priority)
    for child in node.children.reversed() {
        if let found = findScrollNode(x: x, y: y, in: child) {
            return found
        }
    }

    // Check this node
    if node.isScrollView &&
       x >= node.x && x <= node.x + node.width &&
       y >= node.y && y <= node.y + node.height {
        return node
    }

    return nil
}
