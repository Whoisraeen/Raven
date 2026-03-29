# Raven Platform API

Cross-platform OS service bindings that work identically on Windows, macOS, and Linux.

---

## Architecture

```
┌──────────────────────┐
│   Swift Application  │  RavenPlatform.clipboardSetText("Hi")
└────────┬─────────────┘
         │ Swift FFI
         ▼
┌──────────────────────┐
│  CRavenCore (C API)  │  raven_clipboard_set_text("Hi")
└────────┬─────────────┘
         │ Rust extern "C"
         ▼
┌──────────────────────┐
│  raven-core (Rust)   │  platform_api.rs
│  ┌─────────────────┐ │
│  │ Win: PowerShell  │ │
│  │ Mac: pbcopy      │ │
│  │ Lin: xclip       │ │
│  └─────────────────┘ │
└──────────────────────┘
```

---

## Clipboard

### Read
```swift
if let text = RavenPlatform.clipboardGetText() {
    print("Clipboard: \(text)")
}
```

### Write
```swift
RavenPlatform.clipboardSetText("Hello from Raven!")
```

### Platform Backends
| Platform | Read | Write |
|----------|------|-------|
| Windows | `Get-Clipboard` (PowerShell) | `Set-Clipboard` (PowerShell) |
| macOS | `pbpaste` | `pbcopy` |
| Linux | `xclip -selection clipboard -o` | `xclip -selection clipboard` |

---

## File Dialogs

### Open
```swift
if let path = RavenPlatform.openFileDialog(
    title: "Select Image",
    filter: "*.png;*.jpg;*.gif"
) {
    print("Selected: \(path)")
}
```

### Save
```swift
if let path = RavenPlatform.saveFileDialog(
    title: "Export PDF",
    defaultName: "document.pdf"
) {
    print("Saving to: \(path)")
}
```

### Platform Backends
| Platform | Implementation |
|----------|---------------|
| Windows | `System.Windows.Forms.OpenFileDialog` / `SaveFileDialog` via PowerShell |
| macOS | `osascript` → `choose file` / `choose file name` |
| Linux | `zenity --file-selection` (GTK dialog) |

---

## Notifications

### Show
```swift
RavenPlatform.showNotification(
    title: "Download Complete",
    body: "Your file has been saved."
)
```

### Platform Backends
| Platform | Implementation |
|----------|---------------|
| Windows | `Windows.UI.Notifications.ToastNotification` via PowerShell |
| macOS | `osascript` → `display notification` |
| Linux | `notify-send` (libnotify) |

---

## Error Handling

All methods return `nil` or `false` on failure. The `RavenLogger` system captures platform errors:

```swift
if !RavenPlatform.clipboardSetText(text) {
    RavenLogger.error("Failed to write to clipboard")
}
```

---

## Adding New Platform APIs

To add a new OS service:

1. **Rust:** Add the FFI function in `rust/raven-core/src/platform_api.rs`
   - Implement per-platform with `#[cfg(target_os = "...")]`
   - Use `extern "C"` + `#[no_mangle]`
2. **C Header:** Declare in `Sources/CRavenCore/include/raven_core.h`
3. **Swift:** Wrap in `Sources/Raven/Platform/PlatformAPI.swift`

Example:
```rust
#[no_mangle]
pub extern "C" fn raven_my_api() -> i32 {
    my_api_impl()
}

#[cfg(target_os = "windows")]
fn my_api_impl() -> i32 { /* Windows code */ }

#[cfg(target_os = "macos")]
fn my_api_impl() -> i32 { /* macOS code */ }

#[cfg(target_os = "linux")]
fn my_api_impl() -> i32 { /* Linux code */ }
```

---

## Requirements

| Platform | Dependencies |
|----------|-------------|
| Windows | PowerShell 5.1+ (built-in) |
| macOS | `osascript` + `pbcopy`/`pbpaste` (built-in) |
| Linux | `xclip`, `zenity`, `notify-send` (install via package manager) |

Linux package install:
```bash
# Ubuntu/Debian
sudo apt install xclip zenity libnotify-bin

# Fedora
sudo dnf install xclip zenity libnotify

# Arch
sudo pacman -S xclip zenity libnotify
```
