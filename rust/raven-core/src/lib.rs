mod platform;
mod clipboard;
mod file_dialog;

use std::ffi::{c_char, CString};

// MARK: - Core

#[no_mangle]
pub extern "C" fn raven_core_init() -> i32 {
    0
}

#[no_mangle]
pub extern "C" fn raven_core_version() -> *const c_char {
    c"0.1.0".as_ptr()
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
pub extern "C" fn raven_core_clipboard_get() -> *mut c_char {
    clipboard::get_text()
}

#[no_mangle]
pub extern "C" fn raven_core_clipboard_set(text: *const c_char) -> i32 {
    clipboard::set_text(text)
}

// MARK: - File Dialogs

#[no_mangle]
pub extern "C" fn raven_core_open_file_dialog(
    title: *const c_char,
    filter: *const c_char,
) -> *mut c_char {
    file_dialog::open_file(title, filter)
}

#[no_mangle]
pub extern "C" fn raven_core_save_file_dialog(
    title: *const c_char,
    default_name: *const c_char,
) -> *mut c_char {
    file_dialog::save_file(title, default_name)
}

#[no_mangle]
pub extern "C" fn raven_core_select_folder_dialog(title: *const c_char) -> *mut c_char {
    file_dialog::select_folder(title)
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
