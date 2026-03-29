import CRavenCore

// MARK: - RavenCore

/// Swift wrapper around the Rust raven-core static library via C FFI.
enum RavenCore {
    static func initialize() {
        let result = raven_core_init()
        if result != 0 {
            print("Warning: raven_core_init returned \(result)")
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
}
