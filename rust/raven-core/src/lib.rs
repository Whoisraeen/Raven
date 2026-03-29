mod platform;
mod platform_api;

use std::ffi::c_char;

/// Returns the library version as a static C string.
#[no_mangle]
pub extern "C" fn raven_core_version() -> *const c_char {
    c"0.1.0".as_ptr()
}

/// Initialize the core library. Returns 0 on success, nonzero on failure.
#[no_mangle]
pub extern "C" fn raven_core_init() -> i32 {
    0
}

/// Returns the current platform name as a static C string.
#[no_mangle]
pub extern "C" fn raven_core_platform_name() -> *const c_char {
    platform::platform_name()
}

/// Returns the OS version string. Caller must free with raven_core_free_string.
#[no_mangle]
pub extern "C" fn raven_core_os_version() -> *mut c_char {
    platform::os_version()
}

/// Free a string allocated by raven-core.
#[no_mangle]
pub extern "C" fn raven_core_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(std::ffi::CString::from_raw(ptr));
        }
    }
}
