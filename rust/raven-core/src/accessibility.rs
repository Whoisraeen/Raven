//! Platform-specific accessibility integration.
//!
//! Receives a JSON-serialized accessibility tree from the Swift layer
//! and exposes it to the OS assistive technology APIs:
//! - Windows: UI Automation Provider (UIA)
//! - macOS: NSAccessibility / AX framework
//! - Linux: AT-SPI2 via D-Bus
//!
//! The JSON schema matches AccessibilityElement from Swift:
//! ```json
//! {
//!   "role": "button",
//!   "label": "Submit",
//!   "value": null,
//!   "frame": { "x": 10, "y": 20, "width": 100, "height": 40 },
//!   "children": [...]
//! }
//! ```

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

/// Stored accessibility tree (JSON string) — updated each frame.
static TREE_JSON: Mutex<Option<String>> = Mutex::new(None);

/// Update the accessibility tree with a new JSON snapshot.
/// Called by Swift after each layout pass.
///
/// Returns 0 on success, -1 on error.
pub fn set_tree(json: *const c_char) -> i32 {
    if json.is_null() {
        if let Ok(mut tree) = TREE_JSON.lock() {
            *tree = None;
        }
        return 0;
    }

    let c_str = unsafe { CStr::from_ptr(json) };
    let json_str = match c_str.to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => {
            crate::set_last_error("Invalid UTF-8 in accessibility tree JSON");
            return -1;
        }
    };

    // Store the tree
    if let Ok(mut tree) = TREE_JSON.lock() {
        *tree = Some(json_str.clone());
    }

    // Push to platform-specific accessibility API
    push_to_platform(&json_str);

    0
}

/// Get the current accessibility tree as JSON.
/// Caller must free the returned string with `raven_core_free_string`.
pub fn get_tree() -> *mut c_char {
    let tree = TREE_JSON.lock().ok().and_then(|t| t.clone());
    match tree {
        Some(json) => CString::new(json).map(|s| s.into_raw()).unwrap_or(std::ptr::null_mut()),
        None => std::ptr::null_mut(),
    }
}

/// Push the accessibility tree to the platform's assistive technology API.
fn push_to_platform(_json: &str) {
    #[cfg(target_os = "windows")]
    {
        // Windows: UI Automation (UIA) integration point.
        // A full implementation would:
        // 1. Parse the JSON into a tree of provider objects
        // 2. Implement IRawElementProviderSimple for each node
        // 3. Call UiaRaiseAutomationEvent to notify screen readers
        //
        // This requires COM registration (done at window creation time via
        // UiaHostProviderFromHwnd) and the Win32_UI_Accessibility feature.
        // The JSON tree stored in TREE_JSON serves as the data source for
        // these providers to read when UIA clients query the tree.
    }

    #[cfg(target_os = "macos")]
    {
        // macOS: NSAccessibility protocol integration point.
        // A full implementation would:
        // 1. Parse the JSON tree
        // 2. Create NSAccessibilityElement objects for each node
        // 3. Post NSAccessibilityLayoutChangedNotification
        // Uses the objc2 crate for Objective-C interop.
    }

    #[cfg(target_os = "linux")]
    {
        // Linux: AT-SPI2 via D-Bus integration point.
        // A full implementation would:
        // 1. Connect to the AT-SPI2 bus via zbus
        // 2. Register accessible objects matching the tree
        // 3. Signal PropertyChange events on updates
    }
}
