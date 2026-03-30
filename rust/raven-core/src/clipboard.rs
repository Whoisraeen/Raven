use std::ffi::{c_char, CStr, CString};

/// Get the current clipboard text content.
/// Returns a heap-allocated C string that must be freed with `raven_core_free_string`.
/// Returns null if the clipboard is empty or an error occurs.
pub fn get_text() -> *mut c_char {
    let text = get_clipboard_text();
    match text {
        Some(s) => CString::new(s).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Set the clipboard text content.
/// Returns 0 on success, nonzero on failure.
pub fn set_text(text: *const c_char) -> i32 {
    if text.is_null() {
        return -1;
    }
    let c_str = unsafe { CStr::from_ptr(text) };
    let text_str = match c_str.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return -1,
    };
    if set_clipboard_text(&text_str) {
        0
    } else {
        -1
    }
}

// --- Platform-specific implementations ---

#[cfg(target_os = "windows")]
fn get_clipboard_text() -> Option<String> {
    use std::ptr;

    unsafe {
        // OpenClipboard(NULL)
        if OpenClipboard(ptr::null_mut()) == 0 {
            return None;
        }

        let handle = GetClipboardData(CF_UNICODETEXT);
        if handle.is_null() {
            CloseClipboard();
            return None;
        }

        let data = GlobalLock(handle);
        if data.is_null() {
            CloseClipboard();
            return None;
        }

        // data is a *const u16 (UTF-16 null-terminated)
        let wide = data as *const u16;
        let mut len = 0usize;
        const MAX_CLIPBOARD_LEN: usize = 16 * 1024 * 1024; // 16M chars safety limit
        while len < MAX_CLIPBOARD_LEN && *wide.add(len) != 0 {
            len += 1;
        }

        let slice = std::slice::from_raw_parts(wide, len);
        let result = String::from_utf16_lossy(slice);

        GlobalUnlock(handle);
        CloseClipboard();

        Some(result)
    }
}

#[cfg(target_os = "windows")]
fn set_clipboard_text(text: &str) -> bool {
    use std::ptr;

    let wide: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
    let byte_len = wide.len() * 2;

    unsafe {
        if OpenClipboard(ptr::null_mut()) == 0 {
            return false;
        }

        EmptyClipboard();

        let handle = GlobalAlloc(GMEM_MOVEABLE, byte_len);
        if handle.is_null() {
            CloseClipboard();
            return false;
        }

        let dest = GlobalLock(handle);
        if dest.is_null() {
            GlobalFree(handle);
            CloseClipboard();
            return false;
        }

        ptr::copy_nonoverlapping(wide.as_ptr() as *const u8, dest as *mut u8, byte_len);

        GlobalUnlock(handle);
        SetClipboardData(CF_UNICODETEXT, handle);
        CloseClipboard();
        true
    }
}

#[cfg(target_os = "windows")]
const CF_UNICODETEXT: u32 = 13;
#[cfg(target_os = "windows")]
const GMEM_MOVEABLE: u32 = 0x0002;

#[cfg(target_os = "windows")]
extern "system" {
    fn OpenClipboard(hWndNewOwner: *mut std::ffi::c_void) -> i32;
    fn CloseClipboard() -> i32;
    fn EmptyClipboard() -> i32;
    fn GetClipboardData(uFormat: u32) -> *mut std::ffi::c_void;
    fn SetClipboardData(uFormat: u32, hMem: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
    fn GlobalAlloc(uFlags: u32, dwBytes: usize) -> *mut std::ffi::c_void;
    fn GlobalFree(hMem: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
    fn GlobalLock(hMem: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
    fn GlobalUnlock(hMem: *mut std::ffi::c_void) -> i32;
}

#[cfg(target_os = "macos")]
fn get_clipboard_text() -> Option<String> {
    use std::process::Command;
    Command::new("pbpaste")
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
}

#[cfg(target_os = "macos")]
fn set_clipboard_text(text: &str) -> bool {
    use std::io::Write;
    use std::process::{Command, Stdio};
    let mut child = match Command::new("pbcopy")
        .stdin(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(_) => return false,
    };
    if let Some(ref mut stdin) = child.stdin {
        let _ = stdin.write_all(text.as_bytes());
    }
    child.wait().map(|s| s.success()).unwrap_or(false)
}

#[cfg(target_os = "linux")]
fn get_clipboard_text() -> Option<String> {
    use std::process::Command;
    // Try xclip first, then xsel
    Command::new("xclip")
        .args(["-selection", "clipboard", "-o"])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .or_else(|| {
            Command::new("xsel")
                .args(["--clipboard", "--output"])
                .output()
                .ok()
                .and_then(|out| String::from_utf8(out.stdout).ok())
        })
}

#[cfg(target_os = "linux")]
fn set_clipboard_text(text: &str) -> bool {
    use std::io::Write;
    use std::process::{Command, Stdio};
    let mut child = match Command::new("xclip")
        .args(["-selection", "clipboard"])
        .stdin(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(_) => return false,
    };
    if let Some(ref mut stdin) = child.stdin {
        let _ = stdin.write_all(text.as_bytes());
    }
    child.wait().map(|s| s.success()).unwrap_or(false)
}
