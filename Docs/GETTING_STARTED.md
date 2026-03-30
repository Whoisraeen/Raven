# Getting Started with Raven

Build your first Raven app in under 5 minutes.

---

## Prerequisites

Before you begin, install:

1. **Swift 6.0+** — [swift.org/download](https://swift.org/download)
2. **Vulkan SDK** — [vulkan.lunarg.com](https://vulkan.lunarg.com/sdk/home)
3. **Rust toolchain** — [rustup.rs](https://rustup.rs) (for the platform layer)
4. **SDL3** — Already included in `vendor/SDL3/`

Verify installations:
```powershell
swift --version        # Swift 6.x.x
rustc --version        # rustc 1.x.x
glslangValidator --version  # Vulkan SDK shader tools
```

---

## Quick Start with the CLI

```bash
# Install the Raven CLI globally
npm install -g swift-raven

# Check that all tools are present
raven doctor

# Create a new project
raven init my-app
cd my-app

# Build and run
raven build
raven run
```

---

## Manual Setup (Clone the Framework)

```bash
git clone https://github.com/Whoisraeen/Raven.git
cd Raven

# Build the Rust platform core
cd rust/raven-core && cargo build --release && cd ../..

# Build the Swift framework and demo
swift build

# Run the demo
swift run RavenDemo
```

You should see a window showcasing:
- Toggle switches (Dark Mode, Notifications)
- Sliders (Volume, Brightness)
- Pickers (Segmented day/week/month, Dropdown sort)
- Progress bars (determinate + indeterminate)
- Interactive buttons

---

## Your First App

Create a new file `Sources/RavenDemo/main.swift` (or replace the existing one):

```swift
import Raven

let count = StateVar(0)

let app = RavenApp(title: "My First App", width: 800, height: 600) {
    VStack(spacing: 20) {
        Text("Welcome to Raven!")
            .foreground(.white)
            .font(size: 24)
            .padding(16)
            .background(.primary)
            .cornerRadius(8)

        HStack(spacing: 8) {
            Text("Item 1").padding(12).background(.surfaceLight)
            Text("Item 2").padding(12).background(.surfaceLight)
            Text("Item 3").padding(12).background(.surfaceLight)
        }

        Divider()

        Button("Count: \(count.value)") {
            count.value += 1
        }

        Spacer()
    }
    .padding(24)
    .background(.background)
}

app.run()
```

Build and run:
```bash
raven build && raven run
```

---

## Core Concepts

### Views
Everything is a `View`. Primitive views render directly; custom views compose other views:

```swift
struct MyCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Card Title").foreground(.text)
            Text("Description").foreground(.textSecondary)
        }
        .padding(16)
        .background(.surface)
        .cornerRadius(8)
    }
}
```

### State Management
Use `StateVar` for reactive values. Changes automatically trigger re-renders:

```swift
let isDarkMode = StateVar(false)
let volume = StateVar<Float>(0.5)

Toggle("Dark Mode", isOn: isDarkMode.binding)
Slider(value: volume.binding, in: 0...1)
```

### Theming
Raven ships with dark (default) and light themes. Customize via `Theme.current`:

```swift
Theme.current = Theme.light  // Switch to light mode

// Or customize:
var custom = Theme.dark
custom.colors.primary = Color(0.90, 0.30, 0.30)
Theme.current = custom
```

### Platform APIs
Access OS services that work identically on Windows, macOS, and Linux:

```swift
// Clipboard
RavenPlatform.clipboardSetText("Hello from Raven!")
let text = RavenPlatform.clipboardGetText()

// File dialogs
let path = RavenPlatform.openFileDialog(title: "Select Image", filter: "*.png;*.jpg")

// Notifications
RavenPlatform.showNotification(title: "Download Complete", body: "Your file is ready.")
```

---

## Available Components

| Component | Usage | Description |
|-----------|-------|-------------|
| `Text("...")` | Display text | Renders using SDF font atlas |
| `Button("...", action: {})` | Clickable button | Label + action closure |
| `Toggle("...", isOn: binding)` | On/off switch | Boolean toggle |
| `Slider(value: binding)` | Draggable range | Float value selector |
| `Picker("...", selection: binding, options: [...])` | Selection control | Segmented or dropdown |
| `ProgressView("...", value: 0.5)` | Progress bar | Determinate or indeterminate |
| `TextField("...", text: binding)` | Text input | Keyboard input with cursor |
| `Spacer()` | Flexible space | Expands to fill |
| `Divider()` | Separator line | Thin horizontal rule |
| `VStack { }` / `HStack { }` / `ZStack { }` | Layout stacks | Vertical, horizontal, layered |
| `ScrollView { }` | Scrollable area | Mouse wheel support |
| `TabView { }` | Tab navigation | Bottom tab bar |
| `NavigationView { }` | Nav container | Title bar + content |
| `Image("path")` | Image display | PNG/JPG via stb_image |

---

## Available Modifiers

| Modifier | Description |
|----------|-------------|
| `.padding(Float)` | Add equal padding on all sides |
| `.padding(top:leading:bottom:trailing:)` | Add per-edge padding |
| `.background(Color)` | Set background color |
| `.foreground(Color)` | Set text/foreground color |
| `.frame(width:height:)` | Set fixed dimensions |
| `.cornerRadius(Float)` | Round corners |
| `.pickerStyle(.menu)` | Switch picker to dropdown mode |
| `.sheet(isPresented: binding) { }` | Modal overlay |
| `.accessibilityLabel("text")` | Screen reader label |

---

## Colors

Raven includes a curated dark-mode color palette:

| Color | Description |
|-------|-------------|
| `.primary` | Primary action color (blue) |
| `.secondary` | Secondary text and borders |
| `.accent` | Accent highlights (green) |
| `.background` | App background (near-black) |
| `.surface` | Card/container background |
| `.surfaceLight` | Elevated surface |
| `.text` | Primary text (near-white) |
| `.textSecondary` | Secondary text (gray) |
| `.error` / `.success` / `.warning` | Semantic colors |
| `Color(r, g, b, a)` | Custom RGBA (0-1 range) |

---

## 8. Debugging

In debug builds, Raven automatically enables Vulkan validation layers for API error detection. Messages appear in stderr:

```
[VULKAN-ERROR] [VALIDATION] Invalid image layout...
[VULKAN-WARNING] [PERF] Suboptimal swapchain...
```

The structured logger provides severity-tagged output:
```swift
RavenLogger.minimumLevel = .debug  // Show all messages
```

---

## Next Steps

- Read the [Component API Reference](COMPONENT_API_REFERENCE.md) for detailed component docs
- Read the [API Reference](API_REFERENCE.md) for complete type documentation
- Explore the [Architecture](ARCHITECTURE.md) to understand how Raven works
- Check the [Development Checklist](Development%20Checklist.md) for the project roadmap
- Read the [Framework Document](RAVEN_FRAMEWORK_DOCUMENT.md) for the full product vision
