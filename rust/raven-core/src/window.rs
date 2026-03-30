use std::ffi::c_void;

#[cfg(target_os = "windows")]
use windows_sys::Win32::Foundation::HWND;
#[cfg(target_os = "windows")]
use windows_sys::Win32::UI::WindowsAndMessaging::{
    ShowWindow, SW_MINIMIZE, SW_MAXIMIZE, SW_RESTORE, GWL_STYLE, SetWindowLongPtrW,
    GetWindowLongPtrW, WS_CAPTION, WS_THICKFRAME, WS_MINIMIZEBOX, WS_MAXIMIZEBOX, WS_SYSMENU,
    SetWindowPos, SWP_FRAMECHANGED, SWP_NOMOVE, SWP_NOSIZE, SWP_NOZORDER,
    SendMessageW, WM_CLOSE,
};

/// Minimize the native window.
/// Returns -1 if the hwnd is null or the platform is unsupported.
pub fn minimize(hwnd: *mut c_void) -> i32 {
    if hwnd.is_null() {
        crate::set_last_error("window::minimize called with null hwnd");
        return -1;
    }
    #[cfg(target_os = "windows")]
    unsafe { ShowWindow(hwnd as HWND, SW_MINIMIZE); }

    #[cfg(not(target_os = "windows"))]
    {
        crate::set_last_error("window::minimize not implemented on this platform");
        return -1;
    }

    #[cfg(target_os = "windows")]
    0
}

/// Maximize or restore the native window.
pub fn maximize(hwnd: *mut c_void) -> i32 {
    if hwnd.is_null() {
        crate::set_last_error("window::maximize called with null hwnd");
        return -1;
    }
    #[cfg(target_os = "windows")]
    unsafe { ShowWindow(hwnd as HWND, SW_MAXIMIZE); }

    #[cfg(not(target_os = "windows"))]
    {
        crate::set_last_error("window::maximize not implemented on this platform");
        return -1;
    }

    #[cfg(target_os = "windows")]
    0
}

/// Close the native window.
pub fn close(hwnd: *mut c_void) -> i32 {
    if hwnd.is_null() {
        crate::set_last_error("window::close called with null hwnd");
        return -1;
    }
    #[cfg(target_os = "windows")]
    unsafe { SendMessageW(hwnd as HWND, WM_CLOSE, 0, 0); }

    #[cfg(not(target_os = "windows"))]
    {
        crate::set_last_error("window::close not implemented on this platform");
        return -1;
    }

    #[cfg(target_os = "windows")]
    0
}

/// Strip the native window chrome to make it frameless but resizable.
pub fn set_borderless(hwnd: *mut c_void, borderless: bool) -> i32 {
    if hwnd.is_null() {
        crate::set_last_error("window::set_borderless called with null hwnd");
        return -1;
    }
    #[cfg(target_os = "windows")]
    unsafe {
        let handle = hwnd as HWND;
        let mut style = GetWindowLongPtrW(handle, GWL_STYLE) as u32;

        if borderless {
            style &= !(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
        } else {
            style |= WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU;
        }

        SetWindowLongPtrW(handle, GWL_STYLE, style as isize);
        SetWindowPos(
            handle,
            0,
            0,
            0,
            0,
            0,
            SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER,
        );
    }

    #[cfg(not(target_os = "windows"))]
    {
        let _ = borderless;
        crate::set_last_error("window::set_borderless not implemented on this platform");
        return -1;
    }

    #[cfg(target_os = "windows")]
    0
}
