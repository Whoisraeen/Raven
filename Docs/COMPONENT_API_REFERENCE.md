# Raven UI Components — API Reference

This document covers the complete set of built-in UI components available in the Raven framework. All components follow SwiftUI-inspired declarative syntax and render identically across Windows, macOS, and Linux via the Vulkan pipeline.

---

## Primitives

### Text
Displays a read-only string.

```swift
Text("Hello, Raven!")
    .foreground(.white)
    .padding(16)
```

### Button
A clickable interactive element that triggers an action.

```swift
Button("Submit") {
    print("Submitted!")
}
```

### Spacer
A flexible element that expands to fill available space within stacks.

```swift
VStack {
    Text("Top")
    Spacer()
    Text("Bottom")
}
```

### Divider
A thin horizontal line used to separate content sections.

```swift
VStack {
    Text("Above")
    Divider()
    Text("Below")
}
```

---

## Form Controls

### TextField
A text input field with cursor, focus, and keyboard support.

```swift
let name = StateVar("")

TextField("Enter name…", text: name.binding)
    .padding(12)
    .background(.surface)
```

### Toggle
A boolean on/off switch. Renders as a capsule track with a sliding thumb.

```swift
let isDarkMode = StateVar(false)

Toggle("Dark Mode", isOn: isDarkMode.binding)
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Text displayed next to the switch |
| `isOn` | `Binding<Bool>` | Two-way binding to the boolean state |

**Behavior:** Click anywhere on the toggle (label or track) to flip the value. The track color transitions between `Theme.current.colors.trackBackground` (off) and `Theme.current.colors.primary` (on).

### Slider
A horizontal draggable control for selecting a `Float` value within a range.

```swift
let volume = StateVar<Float>(0.5)

// Basic (0 to 1):
Slider(value: volume.binding)

// Custom range:
Slider(value: volume.binding, in: 0...100)

// With step snapping:
Slider(value: volume.binding, in: 0...100, step: 10)
```

| Property | Type | Description |
|----------|------|-------------|
| `value` | `Binding<Float>` | Two-way binding to the current value |
| `range` | `ClosedRange<Float>` | Valid value range (default: `0...1`) |
| `step` | `Float?` | Optional step increment for snapping |

**Behavior:** Click or drag on the slider to set the value. The thumb follows the mouse in real-time during drag. If `step` is specified, the value snaps to the nearest multiple.

### Picker
A selection control for choosing from a list of string options. Supports two visual styles.

```swift
let selected = StateVar(0)

// Segmented control (default):
Picker("View", selection: selected.binding, options: ["Day", "Week", "Month"])

// Dropdown menu:
Picker("Sort By", selection: selected.binding, options: ["Name", "Date", "Size"])
    .pickerStyle(.menu)
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Label text (optional) |
| `selection` | `Binding<Int>` | Two-way binding to the selected index |
| `options` | `[String]` | List of option strings |

#### Picker Styles

| Style | Description |
|-------|-------------|
| `.segmented` | Inline horizontal buttons (default). All options visible. |
| `.menu` | Dropdown that expands on click to reveal the option list. |

```swift
Picker("Sort", selection: sort.binding, options: ["Name", "Date"])
    .pickerStyle(.menu)
```

---

## Feedback

### ProgressView
A progress bar showing completion state. Can be determinate or indeterminate.

```swift
// Determinate:
ProgressView("Downloading…", value: 0.65)

// Custom total:
ProgressView("Files processed", value: 42, total: 100)

// Indeterminate:
ProgressView("Loading…")
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Text displayed above the bar |
| `value` | `Float?` | Current progress. `nil` = indeterminate. |
| `total` | `Float` | Maximum value (default: `1.0`) |

---

## Navigation

### TabView
A tab-based navigation container with a bottom tab bar.

```swift
let selectedTab = StateVar(0)

TabView(selection: selectedTab.binding) {
    Text("Home Content").tabItem("Home", index: 0)
    Text("Settings Content").tabItem("Settings", index: 1)
    Text("Profile Content").tabItem("Profile", index: 2)
}
```

| Property | Type | Description |
|----------|------|-------------|
| `selection` | `Binding<Int>` | Currently selected tab index |
| `tabs` | `[TabItem]` | Tab items built with `@TabBuilder` |

### NavigationView
A navigation container with a title bar.

```swift
NavigationView(title: "Settings") {
    VStack {
        Text("App preferences...")
        Divider()
        Toggle("Dark Mode", isOn: darkMode.binding)
    }
    .padding(16)
}
```

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Title displayed in the navigation bar |
| `content` | `@ViewBuilder` | Root content view |

### Sheet (Modal)
A modal overlay presented on top of existing content.

```swift
let showSheet = StateVar(false)

VStack {
    Button("Show Settings") { showSheet.value = true }
}
.sheet(isPresented: showSheet.binding) {
    VStack {
        Text("Modal Content")
        Button("Close") { showSheet.value = false }
    }
    .padding(24)
    .background(.surface)
    .cornerRadius(12)
}
```

---

## Layout

### VStack / HStack / ZStack
Stack containers for vertical, horizontal, and layered layouts.

```swift
VStack(alignment: .leading, spacing: 12) { ... }
HStack(alignment: .center, spacing: 8) { ... }
ZStack { ... }
```

### ScrollView
A scrollable container with mouse wheel support.

```swift
ScrollView(.vertical) { ... }
```

---

## Images

### Image
Displays an image from a file path.

```swift
Image("assets/logo.png")
```

---

## View Modifiers

All views support the following modifier chain:

```swift
Text("Hello")
    .padding(16)                    // Uniform padding
    .padding(top: 8, leading: 12)   // Per-edge padding
    .background(.surface)           // Background color
    .foreground(.white)             // Text/foreground color
    .frame(width: 200, height: 44)  // Fixed dimensions
    .cornerRadius(8)                // Rounded corners
    .pickerStyle(.menu)             // Picker-specific style
    .sheet(isPresented: binding) {} // Modal overlay
    .accessibilityLabel("Greeting") // Accessibility label
    .accessibilityValue("Hello")    // Accessibility value
    .accessibilityHidden()          // Hide from screen readers
    .accessibilityRole(.button)     // Override a11y role
    .tabItem("Home", index: 0)      // TabView tab label
```

---

## Theme System

Raven provides a centralized theme with design tokens:

```swift
// Switch to light mode:
Theme.current = Theme.light

// Customize:
var theme = Theme.dark
theme.colors.primary = Color(0.90, 0.30, 0.30)
theme.typography.defaultFontSize = 18
theme.spacing.lg = 20
theme.shapes.md = 12
Theme.current = theme
```

### Theme Tokens

| Category | Tokens |
|----------|--------|
| **Colors** | primary, secondary, accent, background, surface, surfaceLight, text, textSecondary, buttonText, error, success, warning, trackBackground, thumbColor, divider |
| **Typography** | defaultFontSize, titleFontSize, headlineFontSize, captionFontSize, monospaceFontSize |
| **Spacing** | xxs (2), xs (4), sm (8), md (12), lg (16), xl (24), xxl (32) |
| **Shapes** | sm (4), md (8), lg (12), xl (16), full (9999 = capsule) |

---

## Platform APIs

Cross-platform OS services via Rust FFI. All methods work identically on Windows, macOS, and Linux.

```swift
// Clipboard
let text = RavenPlatform.clipboardGetText()
RavenPlatform.clipboardSetText("Copied!")

// File Dialogs
let path = RavenPlatform.openFileDialog(title: "Open", filter: "*.png;*.jpg")
let savePath = RavenPlatform.saveFileDialog(title: "Save As", defaultName: "untitled.txt")

// Notifications
RavenPlatform.showNotification(title: "Complete", body: "Your export finished.")
```

---

## Logging

Structured logging with severity levels:

```swift
RavenLogger.debug("Layout pass took 2.3ms")
RavenLogger.info("Renderer initialized")
RavenLogger.warning("Atlas near capacity")
RavenLogger.error("Failed to load font")
RavenLogger.critical("Vulkan device lost")

// Filter noisy messages:
RavenLogger.minimumLevel = .warning
```

---

## Vulkan Validation Layers

In debug builds, Raven enables `VK_EXT_debug_utils` + `VK_LAYER_KHRONOS_validation` automatically. Messages appear in stderr:

```
[VULKAN-ERROR] [VALIDATION] Invalid image layout transition...
[VULKAN-WARNING] [PERF] Suboptimal swapchain image count...
```

**Release builds:** Validation disabled by default. Enable via `RAVEN_VULKAN_DEBUG=1` environment variable.

---

## Hot Reload

Raven includes an advanced hot reload system with state preservation. Source file changes are detected automatically, and the view tree is rebuilt while keeping application state intact.

### Auto-Enabled in Debug
Hot reload is active by default in `DEBUG` builds. No setup needed — just edit your `.swift` files and save.

### State Preservation
Use `.preserveOnReload()` to keep state across reloads:

```swift
let counter = StateVar(0).preserveOnReload("counter")
let userName = StateVar("").preserveOnReload("userName")
let isDarkMode = StateVar(false).preserveOnReload("darkMode")
```

Without `.preserveOnReload()`, state resets to its initial value on each file change.

### Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `RAVEN_HOT_RELOAD` | `1` (debug) / `0` (release) | Enable/disable hot reload |
| `RAVEN_WATCH_PATHS` | `Sources/` | Comma-separated directories to watch |
| `RAVEN_WATCH_INTERVAL` | `500` | File poll interval in milliseconds |

### Statistics

```swift
let stats = HotReloadEngine.shared.statistics
print("Reloads: \(stats.reloadCount)")
print("Files watched: \(stats.watchedFileCount)")
```

### Status Callbacks

```swift
HotReloadEngine.shared.onStatusChange = { status in
    switch status {
    case .reloading(let changes, let n):
        print("Reload #\(n): \(changes.count) files changed")
    default: break
    }
}
```
