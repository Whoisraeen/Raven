use std::ffi::{c_char, CStr, CString};

/// Show an "Open File" dialog and return the selected path.
/// `filter` is a null-terminated C string like "Text Files\0*.txt\0All Files\0*.*\0"
/// Returns null if cancelled or on error.
pub fn open_file(title: *const c_char, filter: *const c_char) -> *mut c_char {
    let title_str = if title.is_null() {
        "Open File".to_string()
    } else {
        unsafe { CStr::from_ptr(title) }
            .to_str()
            .unwrap_or("Open File")
            .to_string()
    };

    let filter_str = if filter.is_null() {
        None
    } else {
        Some(
            unsafe { CStr::from_ptr(filter) }
                .to_str()
                .unwrap_or("")
                .to_string(),
        )
    };

    match show_open_dialog(&title_str, filter_str.as_deref()) {
        Some(path) => CString::new(path).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Show a "Save File" dialog and return the selected path.
/// Returns null if cancelled or on error.
pub fn save_file(title: *const c_char, default_name: *const c_char) -> *mut c_char {
    let title_str = if title.is_null() {
        "Save File".to_string()
    } else {
        unsafe { CStr::from_ptr(title) }
            .to_str()
            .unwrap_or("Save File")
            .to_string()
    };

    let default_str = if default_name.is_null() {
        None
    } else {
        Some(
            unsafe { CStr::from_ptr(default_name) }
                .to_str()
                .unwrap_or("")
                .to_string(),
        )
    };

    match show_save_dialog(&title_str, default_str.as_deref()) {
        Some(path) => CString::new(path).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Show a "Select Folder" dialog and return the selected path.
/// Returns null if cancelled or on error.
pub fn select_folder(title: *const c_char) -> *mut c_char {
    let title_str = if title.is_null() {
        "Select Folder".to_string()
    } else {
        unsafe { CStr::from_ptr(title) }
            .to_str()
            .unwrap_or("Select Folder")
            .to_string()
    };

    match show_folder_dialog(&title_str) {
        Some(path) => CString::new(path).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

// --- Windows implementations using COM/IFileDialog ---

#[cfg(target_os = "windows")]
fn show_open_dialog(title: &str, _filter: Option<&str>) -> Option<String> {
    use std::process::Command;
    // Use PowerShell's OpenFileDialog for simplicity and reliability.
    let script = format!(
        r#"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = '{}'; if ($d.ShowDialog() -eq 'OK') {{ $d.FileName }}"#,
        title.replace('\'', "''")
    );
    Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "windows")]
fn show_save_dialog(title: &str, default_name: Option<&str>) -> Option<String> {
    use std::process::Command;
    let filename_part = match default_name {
        Some(name) => format!("$d.FileName = '{}'; ", name.replace('\'', "''")),
        None => String::new(),
    };
    let script = format!(
        r#"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.SaveFileDialog; $d.Title = '{}'; {}if ($d.ShowDialog() -eq 'OK') {{ $d.FileName }}"#,
        title.replace('\'', "''"),
        filename_part
    );
    Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "windows")]
fn show_folder_dialog(title: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = '{}'; if ($d.ShowDialog() -eq 'OK') {{ $d.SelectedPath }}"#,
        title.replace('\'', "''")
    );
    Command::new("powershell")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

// --- macOS implementations using osascript ---

#[cfg(target_os = "macos")]
fn show_open_dialog(title: &str, _filter: Option<&str>) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"choose file with prompt "{}""#,
        title.replace('"', "\\\"")
    );
    Command::new("osascript")
        .args(["-e", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| {
            // osascript returns "alias Macintosh HD:Users:..." — convert to POSIX
            let trimmed = s.trim();
            if trimmed.starts_with("alias ") {
                trimmed
                    .strip_prefix("alias ")
                    .unwrap_or(trimmed)
                    .replacen(":", "/", 1)
                    .replace(':', "/")
            } else {
                trimmed.to_string()
            }
        })
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "macos")]
fn show_save_dialog(title: &str, default_name: Option<&str>) -> Option<String> {
    use std::process::Command;
    let default_part = match default_name {
        Some(name) => format!(r#" default name "{}""#, name.replace('"', "\\\"")),
        None => String::new(),
    };
    let script = format!(
        r#"choose file name with prompt "{}"{}"#,
        title.replace('"', "\\\""),
        default_part
    );
    Command::new("osascript")
        .args(["-e", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "macos")]
fn show_folder_dialog(title: &str) -> Option<String> {
    use std::process::Command;
    let script = format!(
        r#"choose folder with prompt "{}""#,
        title.replace('"', "\\\"")
    );
    Command::new("osascript")
        .args(["-e", &script])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

// --- Linux implementations using zenity ---

#[cfg(target_os = "linux")]
fn show_open_dialog(title: &str, _filter: Option<&str>) -> Option<String> {
    use std::process::Command;
    Command::new("zenity")
        .args(["--file-selection", "--title", title])
        .output()
        .ok()
        .and_then(|out| {
            if out.status.success() {
                String::from_utf8(out.stdout).ok()
            } else {
                None
            }
        })
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "linux")]
fn show_save_dialog(title: &str, default_name: Option<&str>) -> Option<String> {
    use std::process::Command;
    let mut args = vec!["--file-selection", "--save", "--title", title];
    let filename_arg;
    if let Some(name) = default_name {
        filename_arg = format!("--filename={}", name);
        args.push(&filename_arg);
    }
    Command::new("zenity")
        .args(&args)
        .output()
        .ok()
        .and_then(|out| {
            if out.status.success() {
                String::from_utf8(out.stdout).ok()
            } else {
                None
            }
        })
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[cfg(target_os = "linux")]
fn show_folder_dialog(title: &str) -> Option<String> {
    use std::process::Command;
    Command::new("zenity")
        .args(["--file-selection", "--directory", "--title", title])
        .output()
        .ok()
        .and_then(|out| {
            if out.status.success() {
                String::from_utf8(out.stdout).ok()
            } else {
                None
            }
        })
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}
