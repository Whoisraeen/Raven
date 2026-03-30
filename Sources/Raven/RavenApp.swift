import CSDL3
import CVulkan
import Foundation
#if canImport(ucrt)
import ucrt
#endif


// MARK: - RenderThread

/// Manages a dedicated thread for Vulkan command recording and submission.
/// Decouples the UI thread (layout/view rebuild) from the GPU (VSync/sync).
private final class RenderThread: @unchecked Sendable {
    private let renderer: VulkanRenderer
    private let queue = DispatchQueue(label: "com.raven.render", qos: .userInteractive)
    
    private let lock = RavenLock()
    private var pendingFrame: RenderFrame?
    private var isBusy = false

    init(renderer: VulkanRenderer) {
        self.renderer = renderer
    }

    /// Submit a new frame to the render thread.
    /// Returns true if the frame was accepted, false if the thread is busy.
    func submit(frame: RenderFrame) -> Bool {
        return lock.withLock {
            if isBusy { return false }
            pendingFrame = frame
            isBusy = true
            
            queue.async { [weak self] in
                self?.processFrame()
            }
            return true
        }
    }

    private func processFrame() {
        let frame = lock.withLock { pendingFrame }
        guard let frame = frame else {
            lock.withLock { isBusy = false }
            return
        }

        // Texture updates MUST happen on the render thread
        // (Vulkan resources are owned/managed here)
        for imgCmd in frame.imageCommands {
            renderer.imageRenderer.loadImage(path: imgCmd.textureId)
        }
        renderer.textRenderer.updateAtlasIfNeeded()

        // Submit the frame to Vulkan
        renderer.drawFrame(frame)

        lock.withLock {
            pendingFrame = nil
            isBusy = false
        }
    }
}

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
        // Disable stdout buffering so crash diagnostics are visible
        #if os(Windows)
        setvbuf(stdout, nil, _IONBF, 0)
        #endif

        // Initialize Rust core
        RavenCore.initialize()
        RavenLogger.info("Raven Core v\(RavenCore.version) on \(RavenCore.platformName) (\(RavenCore.osVersion))")

        // SDL Init
        guard SDL_Init(SDL_INIT_VIDEO) else {
            fail("SDL_Init failed: \(currentSDLError())")
        }
        defer { SDL_Quit() }

        let windowFlags = sdlWindowResizableFlag | sdlWindowVulkanFlag | sdlWindowHighPixelDensityFlag

        guard let window = SDL_CreateWindow(title, Int32(width), Int32(height), windowFlags) else {
            fail("SDL_CreateWindow failed: \(currentSDLError())")
        }
        defer { SDL_DestroyWindow(window) }

        // Attach to the WindowManager for global native configuration
        WindowManager.shared.window = window
        WindowManager.shared.refreshScaleFactor()

        RavenLogger.info("Window created, initializing Vulkan renderer...")

        // Create renderer
        let renderer = VulkanRenderer(window: window)
        RavenLogger.info("Renderer initialized successfully")
        defer { renderer.destroy() }

        // Initialize Render Thread
        let renderThread = RenderThread(renderer: renderer)

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

        RavenLogger.info("Raven — \(title)")
        RavenLogger.info("Press ESC or close the window to exit.")

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
            let profiler = Profiler.shared
            profiler.begin(.frameTotal)

            let currentTicks = SDL_GetTicks()
            let deltaTime = Double(currentTicks - lastTicks) / 1000.0
            lastTicks = currentTicks

            // Tick animation engine (interpolates values and notifies state tracker if changed)
            profiler.begin(.animation)
            AnimationEngine.shared.tick(deltaTime: deltaTime)
            profiler.end(.animation)

            profiler.begin(.eventHandling)
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
                    let scale = WindowManager.shared.scaleFactor
                    let mouseX = Float(event.button.x) / scale
                    let mouseY = Float(event.button.y) / scale
                    if let root = rootNode {
                        EventDispatcher.handleClick(x: mouseX, y: mouseY, root: root)
                    }

                case UInt32(SDL_EVENT_MOUSE_WHEEL.rawValue):
                    // Mouse wheel — scroll the nearest ScrollView under cursor
                    let scale = WindowManager.shared.scaleFactor
                    let scrollAmount = Float(event.wheel.y) * -30.0  // negative = scroll down
                    if let root = rootNode {
                        // Find the scroll container under the mouse
                        if let scrollNode = findScrollNode(x: Float(event.wheel.mouse_x) / scale,
                                                           y: Float(event.wheel.mouse_y) / scale,
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
                    let scale = WindowManager.shared.scaleFactor
                    let mouseX = Float(event.motion.x) / scale
                    let mouseY = Float(event.motion.y) / scale
                    EventDispatcher.handleMouseMotion(x: mouseX, y: mouseY)

                case UInt32(SDL_EVENT_MOUSE_BUTTON_UP.rawValue):
                    // Mouse button release — end slider drag
                    EventDispatcher.handleMouseUp()

                case UInt32(SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED.rawValue),
                     UInt32(SDL_EVENT_WINDOW_RESIZED.rawValue):
                    renderer.recreateSwapchain()
                    StateTracker.shared.markDirty()

                case UInt32(SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED.rawValue):
                    WindowManager.shared.refreshScaleFactor()
                    renderer.recreateSwapchain()
                    StateTracker.shared.markDirty()

                default:
                    break
                }
            }

            profiler.end(.eventHandling)

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
                var currentRenderDirtyRect: RenderDirtyRect? = nil

                if needsRebuild {
                    // Re-build view tree (captures current state values)
                    profiler.begin(.viewResolve)
                    EnvironmentStore.shared.reset()
                    let content = contentBuilder()
                    let resolved = ViewResolver.resolve(content, path: "root")
                    profiler.end(.viewResolve)

                    let scale = WindowManager.shared.scaleFactor
                    let viewportWidth = Float(renderer.swapchainExtent.width) / scale
                    let viewportHeight = Float(renderer.swapchainExtent.height) / scale

                    profiler.begin(.layout)
                    LayoutEngine.resolve(
                        root: resolved,
                        viewportWidth: viewportWidth,
                        viewportHeight: viewportHeight
                    )
                    profiler.end(.layout)

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
                            let x = Int32(max(0, floorf((minX - 1) * scale)))
                            let y = Int32(max(0, floorf((minY - 1) * scale)))
                            let w = UInt32(ceilf((maxX - minX + 2) * scale))
                            let h = UInt32(ceilf((maxY - minY + 2) * scale))
                            currentRenderDirtyRect = RenderDirtyRect(x: x, y: y, width: w, height: h)
                        }
                        currentDirtyPaths.removeAll()
                    }

                    // Store for hit testing
                    rootNode = resolved

                    // Process onAppear/onDisappear lifecycle callbacks
                    processLifecycle(root: resolved)

                    // Build accessibility tree and push to OS assistive technology APIs
                    if let a11yTree = AccessibilityCollector.collect(root: resolved) {
                        RavenCore.setAccessibilityTree(a11yTree.toJSON())
                    }

                    // Collect quads, text commands, and image commands
                    profiler.begin(.renderCollect)
                    let renderOutput = RenderCollector.collect(from: resolved)
                    cachedQuads = renderOutput.quads
                    cachedTextCommands = renderOutput.textCommands
                    cachedImageCommands = renderOutput.imageCommands
                    profiler.end(.renderCollect)

                    needsRebuild = false

                    // Restore state after hot reload (if a snapshot was taken)
                    if StateSnapshotManager.shared.hasSnapshot {
                        StateSnapshotManager.shared.restoreSnapshot()
                    }
                }

                // Always submit a frame to the render thread (it handles VSync synchronization)
                profiler.begin(.gpuSubmit)
                let scale = WindowManager.shared.scaleFactor
                let output = RenderOutput(
                    quads: cachedQuads,
                    textCommands: cachedTextCommands,
                    imageCommands: cachedImageCommands
                ).scaled(by: scale)

                let frame = RenderFrame(
                    quads: output.quads,
                    textCommands: output.textCommands,
                    imageCommands: output.imageCommands,
                    viewportWidth: renderer.swapchainExtent.width,
                    viewportHeight: renderer.swapchainExtent.height,
                    dirtyRect: currentRenderDirtyRect
                )
                
                // Only submit if the render thread isn't still busy with a previous frame
                // This acts as a simple backpressure mechanism (double-buffering)
                _ = renderThread.submit(frame: frame)
                profiler.end(.gpuSubmit)

                profiler.end(.frameTotal)
                profiler.endFrame()
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

// MARK: - API / Ext

extension RavenApp {
    /// Adds a system tray integration using the Rust Native FFI backend.
    public static func addSystemTray(icon: String, onClick: @escaping @Sendable () -> Void) {
        RavenCore.addSystemTray(title: "Raven Application", iconPath: icon, onClick: onClick)
    }

    /// Removes the current system tray icon manually.
    public static func removeSystemTray() {
        RavenCore.removeSystemTray()
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

