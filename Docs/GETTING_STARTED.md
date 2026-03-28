# Getting Started with Raven

Build your first Raven app in under 5 minutes.

---

## Prerequisites

Before you begin, install:

1. **Swift 6.0+** — [swift.org/download](https://swift.org/download)
2. **Rust / Cargo** — [rustup.rs](https://rustup.rs)
3. **Vulkan SDK** — [vulkan.lunarg.com](https://vulkan.lunarg.com/sdk/home)
4. **Node.js 18+** — [nodejs.org](https://nodejs.org) (for the Raven CLI)

SDL3 is already vendored in the repository under `vendor/SDL3/`.

### Verify installations

```bash
swift --version        # Swift version 6.x.x
cargo --version        # cargo 1.x.x
glslangValidator --version  # Vulkan SDK shader compiler
node --version         # v18.x or later
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

# Build the Rust platform layer
cd rust/raven-core
cargo build --release
cd ../..

# Build the Swift framework and demo
swift build

# Run the demo
swift run RavenDemo
```

You should see a window with UI elements rendered via Vulkan.

---

## Your First App

Create a new file `Sources/RavenDemo/main.swift` (or replace the existing one):

```swift
import Raven

let app = RavenApp(title: "My First App", width: 800, height: 600) {
    VStack(spacing: 20) {
        Text("Welcome to Raven!")
            .foreground(.white)
            .font(size: 24)
            .padding(16)
            .background(.primary)

        HStack(spacing: 8) {
            Text("Item 1")
                .padding(12)
                .background(.surfaceLight)

            Text("Item 2")
                .padding(12)
                .background(.surfaceLight)

            Text("Item 3")
                .padding(12)
                .background(.surfaceLight)
        }

        Spacer()

        Button("Click Me") {
            print("Button pressed!")
        }
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

Everything in Raven is a `View`. Views declare their content via a `body` property:

```swift
struct MyView: View {
    var body: some View {
        Text("Hello!")
    }
}
```

### Layout Stacks

Arrange views with `VStack` (vertical), `HStack` (horizontal), or `ZStack` (layered):

```swift
VStack(spacing: 16) {
    Text("Top")
    Text("Middle")
    Text("Bottom")
}
```

### Modifiers

Chain modifiers to customize appearance and behavior:

```swift
Text("Styled")
    .padding(16)
    .background(.blue)
    .foreground(.white)
    .frame(width: 200)
    .cornerRadius(8)
    .opacity(0.9)
    .shadow(radius: 4)
```

### State Management

Use `StateVar` for reactive state that triggers re-renders:

```swift
let count = StateVar(0)

let app = RavenApp(title: "Counter") {
    VStack(spacing: 16) {
        Text("Count: \(count.value)")
            .foreground(.white)
            .font(size: 20)

        HStack(spacing: 12) {
            Button("Increment") { count.value += 1 }
            Button("Decrement") { count.value -= 1 }
        }
    }
    .padding(24)
}
```

### Animations

Wrap state changes in `withAnimation` for smooth transitions:

```swift
Button("Animate") {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        count.value += 1
    }
}
```

### Environment and Themes

Raven includes a theme system with light and dark presets:

```swift
// Set theme via environment
let app = RavenApp(title: "Themed App") {
    VStack {
        Text("Themed text")
            .foreground(.text)
    }
    .background(.background)
}
```

---

## Available Components

| Component | Usage | Description |
|-----------|-------|-------------|
| `Text("...")` | Display text | Renders text with TrueType fonts, supports multi-line and word wrap |
| `Button("...", action: {})` | Clickable button | Label + action closure with hover states |
| `Spacer()` | Flexible space | Expands to fill available space in stacks |
| `VStack { }` | Vertical layout | Stacks children top-to-bottom |
| `HStack { }` | Horizontal layout | Stacks children left-to-right |
| `ZStack { }` | Layered layout | Stacks children on top of each other |
| `FlowStack { }` | Wrapping layout | Horizontal flex-wrap like CSS flexbox |
| `Image("path.png")` | Display image | Loads PNG/JPG/BMP via stb_image |
| `TextField(text: binding)` | Text input | Single-line text input with focus |
| `ScrollView { }` | Scrollable area | Vertical/horizontal scrolling with content clipping |
| `ForEach(items) { }` | Dynamic list | Iterates collections or ranges |
| `List(items) { }` | Scrollable list | ScrollView + VStack + dividers |
| `Divider()` | Separator line | Visual separator between content |
| `NavigationStack { }` | Stack navigation | Push/pop route-based navigation |
| `Sidebar(width:) { } detail: { }` | Two-pane layout | Fixed sidebar + flexible detail |
| `Sheet(isPresented:) { }` | Modal overlay | Binding-controlled modal with backdrop |

---

## Available Modifiers

| Modifier | Description |
|----------|-------------|
| `.padding(Float)` | Equal padding on all sides |
| `.padding(top:leading:bottom:trailing:)` | Per-edge padding |
| `.background(Color)` | Background color |
| `.foreground(Color)` | Text/foreground color |
| `.frame(width:height:)` | Fixed dimensions |
| `.cornerRadius(Float)` | Rounded corners |
| `.font(size: Float)` | Font size |
| `.opacity(Float)` | Transparency (0.0-1.0) |
| `.border(Color, width:)` | Border with color and width |
| `.shadow(color:radius:x:y:)` | Drop shadow |
| `.hidden()` | Hides the view |
| `.disabled()` | Disables interaction |
| `.textWrap(maxWidth: Float)` | Word wrapping at max width |
| `.onTapGesture { }` | Tap handler |
| `.onAppear { }` | Called when view enters the tree |
| `.onDisappear { }` | Called when view leaves the tree |
| `.alignToBaseline()` | Baseline alignment in HStack |
| `.accessibilityLabel(String)` | Accessibility label |
| `.accessibilityValue(String)` | Accessibility value |
| `.accessibilityRole(Role)` | Accessibility role |
| `.accessibilityHidden()` | Hide from accessibility tree |

---

## Colors

Raven includes a curated dark-first color palette:

| Color | Description |
|-------|-------------|
| `.primary` | Blue — primary actions |
| `.background` | Near-black — app background |
| `.surface` | Dark gray — card/container |
| `.surfaceLight` | Medium gray — elevated surface |
| `.text` | Near-white — primary text |
| `.textSecondary` | Gray — secondary text |
| `.red`, `.green`, `.blue`, `.yellow`, `.orange`, `.purple` | Accent colors |
| `.white`, `.black`, `.clear`, `.gray`, `.darkGray` | Standard colors |
| `Color(r, g, b, a)` | Custom RGBA (0.0-1.0) |

---

## CLI Commands

| Command | Description |
|---------|-------------|
| `raven init <name>` | Create a new Raven project |
| `raven build` | Build Rust + Swift (debug) |
| `raven build --release` | Build in release mode |
| `raven run` | Build and run the app |
| `raven run --target=MyApp` | Run a specific target |
| `raven dev` | Watch mode — rebuild on changes |
| `raven bundle` | Bundle the app for distribution |
| `raven bundle --platform=windows` | Bundle for a specific platform |
| `raven clean` | Clean all build artifacts |
| `raven doctor` | Check toolchain prerequisites |
| `raven version` | Print CLI version |

---

## Bundling for Distribution

```bash
# Bundle for the current platform (release build + dependencies)
raven bundle --target=MyApp

# The output goes to bundle/<platform>/
# Windows: .exe + DLLs
# macOS: .app bundle with Info.plist
# Linux: bin/ + lib/ + launcher script
```

---

## Platform Layer (Rust FFI)

Raven uses a Rust static library for platform-specific operations:

```swift
// Clipboard
let text = RavenCore.clipboardGet()
RavenCore.clipboardSet("Hello from Raven")

// File dialogs
let path = RavenCore.openFileDialog(title: "Open", filter: "txt,md")
let savePath = RavenCore.saveFileDialog(title: "Save", defaultName: "doc.txt")
let folder = RavenCore.selectFolderDialog()

// Platform info
print(RavenCore.version)       // "0.1.0"
print(RavenCore.platformName)  // "windows" / "macos" / "linux"
print(RavenCore.osVersion)     // "10.0.26200"
```

---

## Next Steps

- Read the [API Reference](API_REFERENCE.md) for complete type documentation
- Explore the [Architecture](ARCHITECTURE.md) to understand how Raven works
- Check the [Development Checklist](Development%20Checklist.md) for the project roadmap
- Read the [Framework Document](RAVEN_FRAMEWORK_DOCUMENT.md) for the full product vision
