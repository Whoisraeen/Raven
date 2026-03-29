use std::ffi::{c_char, CString, CStr};

// MARK: - Clipboard

/// Get text from the system clipboard. Returns null if empty.
/// Caller must free the result with raven_core_free_string.
#[no_mangle]
pub extern "C" fn raven_clipboard_get_text() -> *mut c_char {
    let text = clipboard_get_text_impl();
    match text {
        Some(s) => CString::new(s).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Set text to the system clipboard. Returns 0 on success.
#[no_mangle]
pub extern "C" fn raven_clipboard_set_text(text: *const c_char) -> i32 {
    if text.is_null() {
        return -1;
    }
    let c_str = unsafe { CStr::from_ptr(text) };
    let str_slice = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    if clipboard_set_text_impl(str_slice) {
        0
    } else {
        -1
    }
}

// MARK: - File Open Dialog

/// Show a native file open dialog. Returns the selected path or null.
/// Caller must free the result with raven_core_free_string.
#[no_mangle]
pub extern "C" fn raven_file_dialog_open(
    title: *const c_char,
    filter: *const c_char,
) -> *mut c_char {
    let title_str = if title.is_null() {
        "Open File"
    } else {
        unsafe { CStr::from_ptr(title) }.to_str().unwrap_or("Open File")
    };
    let filter_str = if filter.is_null() {
        "*.*"
    } else {
        unsafe { CStr::from_ptr(filter) }.to_str().unwrap_or("*.*")
    };
    match file_open_dialog_impl(title_str, filter_str) {
        Some(path) => CString::new(path).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Show a native file save dialog. Returns the selected path or null.
/// Caller must free the result with raven_core_free_string.
#[no_mangle]
pub extern "C" fn raven_file_dialog_save(
    title: *const c_char,
    default_name: *const c_char,
) -> *mut c_char {
    let title_str = if title.is_null() {
        "Save File"
    } else {
        unsafe { CStr::from_ptr(title) }.to_str().unwrap_or("Save File")
    };
    let name_str = if default_name.is_null() {
        ""
    } else {
        unsafe { CStr::from_ptr(default_name) }.to_str().unwrap_or("")
    };
    match file_save_dialog_impl(title_str, name_str) {
        Some(path) => CString::new(path).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

// MARK: - Notifications

/// Show a native OS notification. Returns 0 on success.
#[no_mangle]
pub extern "C" fn raven_notification_show(
    title: *const c_char,
    body: *const c_char,
) -> i32 {
    let title_str = if title.is_null() {
        "Raven"
    } else {
        unsafe { CStr::from_ptr(title) }.to_str().unwrap_or("Raven")
    };
    let body_str = if body.is_null() {
        ""
    } else {
        unsafe { CStr::from_ptr(body) }.to_str().unwrap_or("")
    };
    if notification_show_impl(title_str, body_str) {
        0
    } else {
        -1
    }
}

// ============================================================================
// Platform Implementations
// ============================================================================

// --- Windows ---

#[cfg(target_os = "windows")]
fn clipboard_get_text_impl() -> Option<String> {
    use std::process::Command;
    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", "Get-Clipboard"])
        .output()
        .ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        None
    }
}

#[cfg(target_os = "windows")]
fn clipboard_set_text_impl(text: &str) -> bool {
    use std::process::Command;
    let cmd = format!("Set-Clipboard -Value '{}'", text.replace('\'', "''"));
    Command::new("powershell")
        .args(["-NoProfile", "-Command", &cmd])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

#[cfg(target_os = "windows")]
fn file_open_dialog_impl(title: &str, filter: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = '{}'; $d.Filter = '{}'; if ($d.ShowDialog() -eq 'OK') {{ $d.FileName }}"#,
        title, filter
    );
    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "windows")]
fn file_save_dialog_impl(title: &str, default_name: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.SaveFileDialog; $d.Title = '{}'; $d.FileName = '{}'; if ($d.ShowDialog() -eq 'OK') {{ $d.FileName }}"#,
        title, default_name
    );
    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "windows")]
fn notification_show_impl(title: &str, body: &str) -> bool {
    use std::process::Command;
    let script = format!(
        r#"[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null; $t = [Windows.UI.Notifications.ToastTemplateType]::ToastText02; $x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($t); $nodes = $x.GetElementsByTagName('text'); $nodes.Item(0).AppendChild($x.CreateTextNode('{}')); $nodes.Item(1).AppendChild($x.CreateTextNode('{}')); $n = [Windows.UI.Notifications.ToastNotification]::new($x); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Raven').Show($n)"#,
        title.replace('\'', ""), body.replace('\'', "")
    );
    Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

// --- macOS ---

#[cfg(target_os = "macos")]
fn clipboard_get_text_impl() -> Option<String> {
    use std::process::Command;
    let output = Command::new("pbpaste").output().ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        None
    }
}

#[cfg(target_os = "macos")]
fn clipboard_set_text_impl(text: &str) -> bool {
    use std::process::Command;
    use std::io::Write;
    let mut child = Command::new("pbcopy")
        .stdin(std::process::Stdio::piped())
        .spawn()
        .ok();
    if let Some(ref mut c) = child {
        if let Some(ref mut stdin) = c.stdin {
            let _ = stdin.write_all(text.as_bytes());
        }
        c.wait().map(|s| s.success()).unwrap_or(false)
    } else {
        false
    }
}

#[cfg(target_os = "macos")]
fn file_open_dialog_impl(title: &str, _filter: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"tell application "System Events" to set frontmost of process "Terminal" to true
set theFile to choose file with prompt "{}"
return POSIX path of theFile"#,
        title
    );
    let output = Command::new("osascript")
        .args(["-e", &script])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "macos")]
fn file_save_dialog_impl(title: &str, default_name: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"set theFile to choose file name with prompt "{}" default name "{}"
return POSIX path of theFile"#,
        title, default_name
    );
    let output = Command::new("osascript")
        .args(["-e", &script])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "macos")]
fn notification_show_impl(title: &str, body: &str) -> bool {
    use std::process::Command;
    let script = format!(
        r#"display notification "{}" with title "{}""#,
        body.replace('"', "\\\""),
        title.replace('"', "\\\"")
    );
    Command::new("osascript")
        .args(["-e", &script])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

// --- Linux ---

#[cfg(target_os = "linux")]
fn clipboard_get_text_impl() -> Option<String> {
    use std::process::Command;
    // Try xclip first, then xsel
    Command::new("xclip")
        .args(["-selection", "clipboard", "-o"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .or_else(|| {
            Command::new("xsel")
                .args(["--clipboard", "--output"])
                .output()
                .ok()
                .filter(|o| o.status.success())
                .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        })
}

#[cfg(target_os = "linux")]
fn clipboard_set_text_impl(text: &str) -> bool {
    use std::process::Command;
    use std::io::Write;
    let mut child = Command::new("xclip")
        .args(["-selection", "clipboard"])
        .stdin(std::process::Stdio::piped())
        .spawn()
        .ok();
    if let Some(ref mut c) = child {
        if let Some(ref mut stdin) = c.stdin {
            let _ = stdin.write_all(text.as_bytes());
        }
        c.wait().map(|s| s.success()).unwrap_or(false)
    } else {
        false
    }
}

#[cfg(target_os = "linux")]
fn file_open_dialog_impl(title: &str, _filter: &str) -> Option<String> {
    use std::process::Command;
    // Use zenity (GTK)
    let output = Command::new("zenity")
        .args(["--file-selection", "--title", title])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "linux")]
fn file_save_dialog_impl(title: &str, default_name: &str) -> Option<String> {
    use std::process::Command;
    let output = Command::new("zenity")
        .args(["--file-selection", "--save", "--title", title, "--filename", default_name])
        .output()
        .ok()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if path.is_empty() { None } else { Some(path) }
    } else {
        None
    }
}

#[cfg(target_os = "linux")]
fn notification_show_impl(title: &str, body: &str) -> bool {
    use std::process::Command;
    Command::new("notify-send")
        .args([title, body])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}
