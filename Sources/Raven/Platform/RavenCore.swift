import CRavenCore

// MARK: - RavenCore

/// Swift wrapper around the Rust raven-core static library via C FFI.
enum RavenCore {
    static func initialize() {
        let result = raven_core_init()
        if result != 0 {
            RavenLogger.warning("raven_core_init returned \(result)")
        }
    }

    static var version: String {
        String(cString: raven_core_version())
    }

    static var platformName: String {
        String(cString: raven_core_platform_name())
    }

    static var osVersion: String {
        guard let ptr = raven_core_os_version() else { return "unknown" }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str
    }

    /// Returns the last error message from a Rust FFI call, or nil if no error.
    static var lastError: String? {
        guard let ptr = raven_core_last_error() else { return nil }
        return String(cString: ptr)
    }

    // MARK: - Clipboard

    /// Get the current clipboard text, or nil if empty/unavailable.
    static func clipboardGet() -> String? {
        guard let ptr = raven_clipboard_get_text() else { return nil }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str
    }

    /// Set the clipboard text. Returns true on success.
    @discardableResult
    static func clipboardSet(_ text: String) -> Bool {
        text.withCString { cStr in
            raven_clipboard_set_text(cStr) == 0
        }
    }

    // MARK: - File Dialogs

    /// Show an open-file dialog. Returns the selected file path, or nil if cancelled.
    static func openFileDialog(title: String = "Open File", filter: String? = nil) -> String? {
        let result = title.withCString { titlePtr in
            (filter ?? "").withCString { filterPtr in
                raven_file_dialog_open(titlePtr, filterPtr)
            }
        }
        guard let ptr = result else { return nil }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str
    }

    /// Show a save-file dialog. Returns the selected file path, or nil if cancelled.
    static func saveFileDialog(title: String = "Save File", defaultName: String? = nil) -> String? {
        let result = title.withCString { titlePtr in
            (defaultName ?? "").withCString { namePtr in
                raven_file_dialog_save(titlePtr, namePtr)
            }
        }
        guard let ptr = result else { return nil }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str
    }

    /// Show a select-folder dialog. Returns the selected folder path, or nil if cancelled.
    static func selectFolderDialog(title: String = "Select Folder") -> String? {
        let result = title.withCString { titlePtr in
            raven_file_dialog_select_folder(titlePtr)
        }
        guard let ptr = result else { return nil }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str
    }

    // MARK: - Notifications

    @discardableResult
    static func showNotification(title: String, body: String) -> Bool {
        title.withCString { tPtr in
            body.withCString { bPtr in
                raven_notification_show(tPtr, bPtr) == 0
            }
        }
    }

    // MARK: - System Tray

    nonisolated(unsafe) private static var _trayClickCallback: (@Sendable () -> Void)?

    static func addSystemTray(title: String, iconPath: String, onClick: @escaping @Sendable () -> Void) {
        _trayClickCallback = onClick

        let cCallback: @convention(c) () -> Void = {
            RavenCore._trayClickCallback?()
        }

        title.withCString { tPtr in
            iconPath.withCString { iPtr in
                raven_tray_add(tPtr, iPtr, cCallback)
            }
        }
    }

    static func removeSystemTray() {
        raven_tray_remove()
        _trayClickCallback = nil
    }

    // MARK: - Window Management (Native Hacks)

    static func windowMinimize(hwnd: UnsafeMutableRawPointer) {
        raven_window_minimize(hwnd)
    }

    static func windowMaximize(hwnd: UnsafeMutableRawPointer) {
        raven_window_maximize(hwnd)
    }

    static func windowClose(hwnd: UnsafeMutableRawPointer) {
        raven_window_close(hwnd)
    }

    static func windowSetBorderless(hwnd: UnsafeMutableRawPointer, borderless: Bool) {
        raven_window_set_borderless(hwnd, borderless)
    }
}
