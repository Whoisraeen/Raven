import CSDL3
import CVulkan
import Foundation


// MARK: - RavenApp

/// The main entry point for a Raven application.
/// Ties together SDL window creation, the Vulkan renderer,
/// the layout engine, and the render collector.
public class RavenApp<Content: View>: @unchecked Sendable {
    private let title: String
    private let width: Int
    private let height: Int
    private let contentBuilder: @Sendable () -> Content

    /// Tracks node IDs from the previous frame for onAppear/onDisappear
    private var previousNodeIDs: Set<AnyHashable> = []
    /// Maps node IDs to their lifecycle callbacks
    private var nodeCallbacks: [AnyHashable: (onAppear: (@Sendable () -> Void)?, onDisappear: (@Sendable () -> Void)?)] = [:]

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
        var currentDirtyPaths: Set<String> = []

        var lastTicks = SDL_GetTicks()

        // Initialize hot reload (debug builds by default, or RAVEN_HOT_RELOAD=1)
        let hotReloadEnabled: Bool = {
            #if DEBUG
            let envDisable = ProcessInfo.processInfo.environment["RAVEN_HOT_RELOAD"]
            return envDisable != "0"  // Enabled unless explicitly disabled
            #else
            return ProcessInfo.processInfo.environment["RAVEN_HOT_RELOAD"] == "1"
            #endif
        }()

        if hotReloadEnabled {
            HotReloadEngine.shared.onReloadNeeded = {
                // Snapshot state before rebuild
                StateSnapshotManager.shared.takeSnapshot()
                // Trigger rebuild on next frame
                StateTracker.shared.markDirty()
            }

            HotReloadEngine.shared.onStatusChange = { status in
                switch status {
                case .started(let paths, let fileCount):
                    RavenLogger.info("🔥 Hot Reload active — \(fileCount) files in \(paths.count) path(s)")
                case .reloading(let changes, let reloadNumber):
                    RavenLogger.info("🔄 Hot Reload #\(reloadNumber) — \(changes.count) file(s) changed")
                case .reloaded(let reloadNumber):
                    RavenLogger.info("✅ Hot Reload #\(reloadNumber) complete")
                case .stopped(let total):
                    RavenLogger.info("Hot Reload stopped (total: \(total) reloads)")
                case .error(let msg):
                    RavenLogger.error("Hot Reload error: \(msg)")
                }
            }

            HotReloadEngine.shared.start()
        }

        while isRunning {
            let currentTicks = SDL_GetTicks()
            let deltaTime = Double(currentTicks - lastTicks) / 1000.0
            lastTicks = currentTicks

            // Tick animation engine (interpolates values and notifies state tracker if changed)
            AnimationEngine.shared.tick(deltaTime: deltaTime)

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
                            if scrollNode.platform == .macOS {
                                // Elastic/Smooth scrolling for macOS feel
                                let currentOffset = scrollNode.scrollStateVar?.value ?? 0
                                let targetOffset = currentOffset + scrollAmount * 2.5
                                AnimationEngine.shared.animate(
                                    duration: 0.15,
                                    from: currentOffset,
                                    to: targetOffset
                                ) { [weak scrollNode] value in
                                    scrollNode?.scrollStateVar?.value = value
                                }
                            } else {
                                // Rigid/Stepped scrolling for Windows/Linux feel
                                scrollNode.scrollStateVar?.value += scrollAmount
                            }
                        }
                    }

                case UInt32(SDL_EVENT_MOUSE_MOTION.rawValue):
                    // Mouse motion — handle slider drag
                    let mouseX = Float(event.motion.x)
                    let mouseY = Float(event.motion.y)
                    EventDispatcher.handleMouseMotion(x: mouseX, y: mouseY)

                case UInt32(SDL_EVENT_MOUSE_BUTTON_UP.rawValue):
                    // Mouse button release — end slider drag
                    EventDispatcher.handleMouseUp()

                default:
                    break
                }
            }

            // Check if any @State/@Published/StateVar changed (or if AnimationEngine triggered a frame)
            if let paths = StateTracker.shared.checkAndClear() {
                // Snapshot positions from the OLD tree to provide 'start' values for the NEW tree
                LayoutNode.previousPositions.removeAll(keepingCapacity: true)
                if let root = rootNode {
                    snapshotPositions(node: root)
                }

                currentDirtyPaths = paths
                needsRebuild = true
            }

            if isRunning {
                var dirtyRect: VkRect2D? = nil

                if needsRebuild {
                    // Re-build view tree (captures current state values)
                    EnvironmentStore.shared.reset()
                    let content = contentBuilder()
                    let resolved = ViewResolver.resolve(content, path: "root")

                    let viewportWidth = Float(renderer.swapchainExtent.width)
                    let viewportHeight = Float(renderer.swapchainExtent.height)

                    LayoutEngine.resolve(
                        root: resolved,
                        viewportWidth: viewportWidth,
                        viewportHeight: viewportHeight
                    )

                    // Calculate dirty rect (damage region optimization)
                    if !currentDirtyPaths.isEmpty {
                        var minX = Float.infinity
                        var minY = Float.infinity
                        var maxX = -Float.infinity
                        var maxY = -Float.infinity

                        for path in currentDirtyPaths {
                            // Find the node in the NEWLY resolved tree
                            if let node = resolved.findNode(by: path) {
                                minX = min(minX, node.x)
                                minY = min(minY, node.y)
                                maxX = max(maxX, node.x + node.width)
                                maxY = max(maxY, node.y + node.height)
                            }
                        }

                        if minX != .infinity {
                            // Expand slightly to avoid sub-pixel clipping artifacts
                            let x = Int32(max(0, floorf(minX - 1)))
                            let y = Int32(max(0, floorf(minY - 1)))
                            let w = UInt32(ceilf(maxX - minX + 2))
                            let h = UInt32(ceilf(maxY - minY + 2))
                            dirtyRect = VkRect2D(offset: VkOffset2D(x: x, y: y),
                                                 extent: VkExtent2D(width: w, height: h))
                        }
                        currentDirtyPaths.removeAll()
                    }

                    // Store for hit testing
                    rootNode = resolved

                    // Process onAppear/onDisappear lifecycle callbacks
                    processLifecycle(root: resolved)

                    // Build accessibility tree (available for screen readers / debugging)
                    let _ = AccessibilityCollector.collect(root: resolved)

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

                    // Restore state after hot reload (if a snapshot was taken)
                    if StateSnapshotManager.shared.hasSnapshot {
                        StateSnapshotManager.shared.restoreSnapshot()
                    }
                }

                // Always present a frame (Vulkan swapchain expects continuous presentation)
                renderer.drawFrame(quads: cachedQuads,
                                   textCommands: cachedTextCommands,
                                   imageCommands: cachedImageCommands,
                                   dirtyRect: dirtyRect)
            }
        }

        // Cleanup hot reload
        if hotReloadEnabled {
            HotReloadEngine.shared.stop()
        }

        RavenLogger.info("Raven exited cleanly.")
    }

    /// Compare current node tree IDs with previous frame to fire onAppear/onDisappear.
    private func processLifecycle(root: LayoutNode) {
        var currentIDs = Set<AnyHashable>()
        var currentCallbacks: [AnyHashable: (onAppear: (@Sendable () -> Void)?, onDisappear: (@Sendable () -> Void)?)] = [:]
        collectLifecycleNodes(root, ids: &currentIDs, callbacks: &currentCallbacks)

        // Fire onAppear for newly appeared nodes
        for id in currentIDs {
            if !previousNodeIDs.contains(id) {
                currentCallbacks[id]?.onAppear?()
            }
        }

        // Fire onDisappear for removed nodes
        for id in previousNodeIDs {
            if !currentIDs.contains(id) {
                nodeCallbacks[id]?.onDisappear?()
            }
        }

        previousNodeIDs = currentIDs
        nodeCallbacks = currentCallbacks
    }

    private func collectLifecycleNodes(_ node: LayoutNode, ids: inout Set<AnyHashable>,
                                       callbacks: inout [AnyHashable: (onAppear: (@Sendable () -> Void)?, onDisappear: (@Sendable () -> Void)?)]) {
        if let id = node.id, (node.onAppear != nil || node.onDisappear != nil) {
            ids.insert(id)
            callbacks[id] = (onAppear: node.onAppear, onDisappear: node.onDisappear)
        }
        for child in node.children {
            collectLifecycleNodes(child, ids: &ids, callbacks: &callbacks)
        }
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

// MARK: - Animation Support

/// Recursively store node positions in the static cache.
private func snapshotPositions(node: LayoutNode) {
    if let id = node.id {
        LayoutNode.previousPositions[id] = (node.x, node.y)
    }
    for child in node.children {
        snapshotPositions(node: child)
    }
}

