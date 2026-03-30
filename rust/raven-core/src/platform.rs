use std::ffi::{c_char, CString};

pub fn platform_name() -> *const c_char {
    #[cfg(target_os = "windows")]
    { c"windows".as_ptr() }

    #[cfg(target_os = "macos")]
    { c"macos".as_ptr() }

    #[cfg(target_os = "linux")]
    { c"linux".as_ptr() }

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    { c"unknown".as_ptr() }
}

pub fn os_version() -> *mut c_char {
    let version = get_os_version();
    CString::new(version)
        .unwrap_or_default()
        .into_raw()
}

#[cfg(target_os = "windows")]
fn get_os_version() -> String {
    use std::process::Command;
    Command::new("cmd")
        .args(["/C", "ver"])
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "Windows (unknown version)".to_string())
}

#[cfg(target_os = "macos")]
fn get_os_version() -> String {
    use std::process::Command;
    Command::new("sw_vers")
        .arg("-productVersion")
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .map(|s| format!("macOS {}", s.trim()))
        .unwrap_or_else(|| "macOS (unknown version)".to_string())
}

#[cfg(target_os = "linux")]
fn get_os_version() -> String {
    std::fs::read_to_string("/etc/os-release")
        .ok()
        .and_then(|content| {
            content
                .lines()
                .find(|line| line.starts_with("PRETTY_NAME="))
                .map(|line| line.trim_start_matches("PRETTY_NAME=").trim_matches('"').to_string())
        })
        .unwrap_or_else(|| "Linux (unknown distribution)".to_string())
}

#[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
fn get_os_version() -> String {
    "Unknown OS".to_string()
}
