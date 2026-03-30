import CSDL3
import Foundation

/// Centralized Window Manager for abstracting UI Chrome, Titlebars, and Native Window API hooks.
public final class WindowManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = WindowManager()

    // The current main SDL Window handle. Assigned by RavenApp during startup.
    public var window: OpaquePointer?

    /// The DPI scale factor of the current display (e.g., 2.0 for Retina).
    /// All layout logic uses logical pixels, which are multiplied by this scale
    /// for physical pixel rendering.
    public var scaleFactor: Float = 1.0

    private init() {}

    /// Query the current display scale factor from SDL and update the internal state.
    public func refreshScaleFactor() {
        guard let window = window else { return }
        self.scaleFactor = SDL_GetWindowDisplayScale(window)
        RavenLogger.info("Display scale updated: \(scaleFactor)x")
    }

    /// Hide or show the default OS window chrome (title bar, borders).
    /// Used when building entirely custom title bars in Raven UI.
    public func setBorderless(_ borderless: Bool) {
        guard let window = window else { return }
        
        // Route mostly through SDL3 as it handles cross-platform Chrome hiding well
        _ = SDL_SetWindowBordered(window, !borderless)
        
        // Optional Native Win32 Frame Hacks via Rust FFI
        if let nativeHandle = nativeWindowHandle {
            RavenCore.windowSetBorderless(hwnd: nativeHandle, borderless: borderless)
        }
    }

    /// Minimize the window.
    public func minimize() {
        guard let window = window else { return }
        _ = SDL_MinimizeWindow(window)
    }

    /// Maximize or restore the window.
    public func maximize() {
        guard let window = window else { return }
        let flags = SDL_GetWindowFlags(window)
        // SDL_WINDOW_MAXIMIZED is 0x0000000000000080 in SDL3
        if (flags & 0x80) != 0 {
            _ = SDL_RestoreWindow(window)
        } else {
            _ = SDL_MaximizeWindow(window)
        }
    }

    /// Request the window to close gracefully via event loop.
    public func close() {
        guard window != nil else { return }
        var event = SDL_Event()
        event.type = UInt32(SDL_EVENT_QUIT.rawValue)
        _ = SDL_PushEvent(&event)
    }

    // MARK: - Native Handles

    /// Gets the raw OS window pointer (HWND on Win32, NSWindow on macOS, etc.)
    public var nativeWindowHandle: UnsafeMutableRawPointer? {
        guard let window = window else { return nil }
        
        let props = SDL_GetWindowProperties(window)
        if props == 0 { return nil }

        // Attempt Windows (HWND)
        if let ptr = SDL_GetPointerProperty(props, "SDL.window.win32.hwnd", nil) {
            return ptr
        }
        
        // Attempt macOS (NSWindow)
        if let ptr = SDL_GetPointerProperty(props, "SDL.window.cocoa.window", nil) {
            return ptr
        }
        
        // Attempt X11
        if let ptr = SDL_GetPointerProperty(props, "SDL.window.x11.window", nil) {
            return ptr
        }
        
        // Attempt Wayland
        if let ptr = SDL_GetPointerProperty(props, "SDL.window.wayland.surface", nil) {
            return ptr
        }

        return nil
    }
}
