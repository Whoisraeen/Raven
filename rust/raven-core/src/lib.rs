mod accessibility;
mod platform;
mod clipboard;
mod file_dialog;
mod notification;
mod tray;
mod window;

use std::ffi::{c_char, c_void, CString};
use std::cell::RefCell;

thread_local! {
    static LAST_ERROR: RefCell<Option<CString>> = RefCell::new(None);
}

fn set_last_error(msg: &str) {
    LAST_ERROR.with(|e| {
        *e.borrow_mut() = CString::new(msg).ok();
    });
}

// MARK: - Core

#[no_mangle]
pub extern "C" fn raven_core_init() -> i32 {
    set_last_error("");
    0
}

/// Returns the last error message, or null if no error.
/// The returned pointer is valid until the next FFI call.
#[no_mangle]
pub extern "C" fn raven_core_last_error() -> *const c_char {
    LAST_ERROR.with(|e| {
        match &*e.borrow() {
            Some(s) if !s.as_bytes().is_empty() => s.as_ptr(),
            _ => std::ptr::null(),
        }
    })
}

#[no_mangle]
pub extern "C" fn raven_core_version() -> *const c_char {
    // Version is injected at build time from /version.json via build.rs
    static VERSION: &[u8] = concat!(env!("RAVEN_VERSION"), "\0").as_bytes();
    VERSION.as_ptr() as *const c_char
}

#[no_mangle]
pub extern "C" fn raven_core_platform_name() -> *const c_char {
    platform::platform_name()
}

#[no_mangle]
pub extern "C" fn raven_core_os_version() -> *mut c_char {
    platform::os_version()
}

// MARK: - Clipboard

#[no_mangle]
pub extern "C" fn raven_clipboard_get_text() -> *mut c_char {
    clipboard::get_text()
}

#[no_mangle]
pub extern "C" fn raven_clipboard_set_text(text: *const c_char) -> i32 {
    clipboard::set_text(text)
}

// MARK: - File Dialogs

#[no_mangle]
pub extern "C" fn raven_file_dialog_open(
    title: *const c_char,
    filter: *const c_char,
) -> *mut c_char {
    file_dialog::open_file(title, filter)
}

#[no_mangle]
pub extern "C" fn raven_file_dialog_save(
    title: *const c_char,
    default_name: *const c_char,
) -> *mut c_char {
    file_dialog::save_file(title, default_name)
}

#[no_mangle]
pub extern "C" fn raven_file_dialog_select_folder(title: *const c_char) -> *mut c_char {
    file_dialog::select_folder(title)
}


// MARK: - Notifications

#[no_mangle]
pub extern "C" fn raven_notification_show(title: *const c_char, body: *const c_char) -> i32 {
    if notification::show(title, body) {
        0
    } else {
        -1
    }
}

// MARK: - System Tray

pub type RavenTrayCallback = extern "C" fn();

#[no_mangle]
pub extern "C" fn raven_tray_add(
    title: *const c_char,
    icon_path: *const c_char,
    on_click: Option<RavenTrayCallback>,
) {
    tray::add(title, icon_path, on_click);
}

#[no_mangle]
pub extern "C" fn raven_tray_remove() {
    tray::remove();
}

// MARK: - Window Handling

#[no_mangle]
pub extern "C" fn raven_window_minimize(hwnd: *mut c_void) {
    window::minimize(hwnd);
}

#[no_mangle]
pub extern "C" fn raven_window_maximize(hwnd: *mut c_void) {
    window::maximize(hwnd);
}

#[no_mangle]
pub extern "C" fn raven_window_close(hwnd: *mut c_void) {
    window::close(hwnd);
}

#[no_mangle]
pub extern "C" fn raven_window_set_borderless(hwnd: *mut c_void, borderless: bool) {
    window::set_borderless(hwnd, borderless);
}

// MARK: - Accessibility

/// Update the accessibility tree with a JSON snapshot.
/// Pass null to clear the tree. Returns 0 on success, -1 on error.
#[no_mangle]
pub extern "C" fn raven_accessibility_set_tree(json: *const c_char) -> i32 {
    accessibility::set_tree(json)
}

/// Get the current accessibility tree as JSON.
/// Returns null if no tree is set. Caller must free with `raven_core_free_string`.
#[no_mangle]
pub extern "C" fn raven_accessibility_get_tree() -> *mut c_char {
    accessibility::get_tree()
}

// MARK: - Memory Management

#[no_mangle]
pub extern "C" fn raven_core_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
