import CRavenCore

// MARK: - Platform API

/// High-level Swift wrapper for cross-platform OS services.
/// These APIs work identically on Windows, macOS, and Linux via Rust FFI.
public enum RavenPlatform {

    // MARK: - Clipboard

    /// Get the current text content of the system clipboard.
    /// Returns nil if the clipboard is empty or contains non-text data.
    public static func clipboardGetText() -> String? {
        guard let ptr = raven_clipboard_get_text() else { return nil }
        let str = String(cString: ptr)
        raven_core_free_string(ptr)
        return str.isEmpty ? nil : str
    }

    /// Set text content to the system clipboard.
    /// Returns true on success.
    @discardableResult
    public static func clipboardSetText(_ text: String) -> Bool {
        text.withCString { cStr in
            raven_clipboard_set_text(cStr) == 0
        }
    }

    // MARK: - File Dialogs

    /// Show a native file open dialog.
    /// - Parameters:
    ///   - title: Dialog window title (default: "Open File")
    ///   - filter: File filter pattern (e.g., "*.swift;*.txt", platform-specific)
    /// - Returns: The selected file path, or nil if cancelled.
    public static func openFileDialog(title: String = "Open File", filter: String = "*.*") -> String? {
        let result = title.withCString { titlePtr in
            filter.withCString { filterPtr in
                raven_file_dialog_open(titlePtr, filterPtr)
            }
        }
        guard let ptr = result else { return nil }
        let path = String(cString: ptr)
        raven_core_free_string(ptr)
        return path.isEmpty ? nil : path
    }

    /// Show a native file save dialog.
    /// - Parameters:
    ///   - title: Dialog window title (default: "Save File")
    ///   - defaultName: Default filename suggestion
    /// - Returns: The selected save path, or nil if cancelled.
    public static func saveFileDialog(title: String = "Save File", defaultName: String = "") -> String? {
        let result = title.withCString { titlePtr in
            defaultName.withCString { namePtr in
                raven_file_dialog_save(titlePtr, namePtr)
            }
        }
        guard let ptr = result else { return nil }
        let path = String(cString: ptr)
        raven_core_free_string(ptr)
        return path.isEmpty ? nil : path
    }

    // MARK: - Notifications

    /// Show a native OS notification.
    /// - Parameters:
    ///   - title: Notification title (bold text)
    ///   - body: Notification body text
    /// - Returns: true on success
    @discardableResult
    public static func showNotification(title: String, body: String = "") -> Bool {
        title.withCString { titlePtr in
            body.withCString { bodyPtr in
                raven_notification_show(titlePtr, bodyPtr) == 0
            }
        }
    }
}
