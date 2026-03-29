use std::ffi::CStr;
use std::os::raw::c_char;

/// Show a native OS notification. Returns true on success.
pub fn show(title: *const c_char, body: *const c_char) -> bool {
    let title_str = if title.is_null() {
        "Raven"
    } else {
        unsafe { CStr::from_ptr(title) }
            .to_str()
            .unwrap_or("Raven")
    };
    let body_str = if body.is_null() {
        ""
    } else {
        unsafe { CStr::from_ptr(body) }
            .to_str()
            .unwrap_or("")
    };
    notification_show_impl(title_str, body_str)
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

#[cfg(target_os = "linux")]
fn notification_show_impl(title: &str, body: &str) -> bool {
    use std::process::Command;
    Command::new("notify-send")
        .args([title, body])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}
