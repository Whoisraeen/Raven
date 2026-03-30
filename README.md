<div align="center">

# Raven

**A Swift-native cross-platform UI framework**

Build beautiful, performant desktop applications with a SwiftUI-inspired declarative API —
powered by Vulkan, no Electron, no web views.

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Vulkan](https://img.shields.io/badge/Vulkan-1.4-red.svg)](https://vulkan.lunarg.com)
[![Platform](https://img.shields.io/badge/Platform-Windows%20|%20macOS%20|%20Linux-blue.svg)](.)
[![License](https://img.shields.io/badge/License-Proprietary-lightgrey.svg)](.)

</div>

---

## What is Raven?

Raven is a **native UI framework** that lets you build cross-platform desktop apps in pure Swift. Instead of wrapping a web browser (like Electron/Tauri), Raven renders directly via Vulkan — giving you native performance, tiny binaries, and pixel-perfect control.

```swift
import Raven

let count = StateVar(0)

let app = RavenApp(title: "My App") {
    VStack(spacing: 16) {
        Text("Hello, Raven!")
            .foreground(.white)
            .padding(16)

        Text("Count: \(count.value)")
            .foreground(.white)

        HStack(spacing: 12) {
            Button("Increment") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    count.value += 1
                }
            }

            Button("Reset") {
                count.value = 0
            }
        }

        Spacer()
    }
    .padding(32)
}

app.run()
```

**Zero Vulkan code. Zero pixel coordinates. Zero GPU knowledge.**

---

## Features

| Category | Feature | Status |
|----------|---------|--------|
| **Rendering** | Vulkan 1.4 GPU rendering | Done |
| | SDF text rendering (TrueType) | Done |
| | Image rendering (PNG/JPG/BMP) | Done |
| **Layout** | VStack / HStack / ZStack | Done |
| | FlowStack (flex-wrap) | Done |
| | Baseline alignment | Done |
| | Padding / Frame / Alignment | Done |
| | Intrinsic size caching | Done |
| **Components** | Text, Button, Spacer, Image | Done |
| | TextField (text input) | Done |
| | ScrollView (vertical/horizontal) | Done |
| **State** | `StateVar` / `@State` / `@Binding` | Done |
| | `@Published` / `ObservableObject` | Done |
| | Dirty tracking with path-based identity | Done |
| **Animation** | Spring physics (analytic DHO) | Done |
| | Easing curves (linear, easeIn, easeOut, easeInOut) | Done |
| | `withAnimation` block API | Done |
| | Layout transition animations | Done |
| **Environment** | `@Environment` property wrapper | Done |
| | Scoped value propagation | Done |
| | Theme system (light/dark, 20 color tokens) | Done |
| **Navigation** | NavigationStack (push/pop) | Done |
| | Sidebar (two-pane layout) | Done |
| | Sheet (modal overlay) | Done |
| **Platform** | Clipboard (get/set) | Done |
| | File dialogs (open/save/folder) | Done |
| | Swift/Rust FFI bridge | Done |
| **Tooling** | `raven build` / `raven run` / `raven dev` | Done |
| | npm CLI (`swift-raven`) | Done |
| **Platforms** | Windows | Done |
| | macOS (MoltenVK) | In Progress |
| | Linux | In Progress |

---

## Quick Start

### Prerequisites

| Dependency | Version | Notes |
|-----------|---------|-------|
| [Swift](https://swift.org/download) | 6.0+ | Windows/macOS/Linux |
| [Rust](https://rustup.rs) | Latest stable | For platform bridge |
| [Vulkan SDK](https://vulkan.lunarg.com/sdk/home) | 1.0+ | GPU rendering |
| [SDL3](https://github.com/libsdl-org/SDL) | 3.4+ | Included in `vendor/` |

### Install the CLI

```bash
npm install -g swift-raven
```

### Build & Run

```bash
# Clone
git clone https://github.com/Whoisraeen/Raven.git
cd Raven

# Check prerequisites
raven doctor

# Build (Rust + Swift)
raven build

# Run the demo
raven run
```

Or without the CLI:

```bash
# Build Rust core
cd rust/raven-core && cargo build && cd ../..

# Build Swift
swift build

# Run
swift run RavenDemo
```

---

## Project Structure

```
Raven/
├── Package.swift                  SPM package definition
├── raven / raven.bat              CLI scripts (bash + Windows)
├── cli/                           npm package (raven-ui-cli)
├── Sources/
│   ├── Raven/                     The framework (import Raven)
│   │   ├── RavenApp.swift         App entry point & event loop
│   │   ├── View.swift             View protocol & ViewBuilder
│   │   ├── ViewResolver.swift     View -> LayoutNode conversion
│   │   ├── LayoutEngine.swift     Two-pass layout system
│   │   ├── LayoutNode.swift       Layout tree node
│   │   ├── State.swift            @State, @Binding, StateVar
│   │   ├── Animation.swift        Spring & easing animations
│   │   ├── Environment.swift      @Environment, EnvironmentValues
│   │   ├── Theme.swift            Semantic color tokens
│   │   ├── Components/            Text, Button, Stacks, ScrollView, etc.
│   │   ├── Renderer/              Vulkan internals
│   │   └── Platform/              Rust FFI bridge (RavenCore.swift)
│   ├── RavenDemo/                 Example app
│   ├── CSDL3/                     SDL3 C module
│   ├── CVulkan/                   Vulkan C module
│   └── CRavenCore/                Rust FFI C module
├── rust/raven-core/               Rust platform library
├── vendor/SDL3/                   SDL3 dependency
├── Docs/                          Documentation
└── Bootstrap/                     Original Vulkan bootstrap
```

---

## Core Concepts

### Declarative Views

```swift
VStack(spacing: 12) {
    Text("Title").foreground(.white)
    HStack(spacing: 8) {
        Button("OK") { /* action */ }
        Button("Cancel") { /* action */ }
    }
    Spacer()
}
.padding(16)
.background(.surface)
```

### Reactive State

```swift
let name = StateVar("World")

// In your view:
Text("Hello, \(name.value)!")
TextField("Name", text: name.binding)
```

### Animations

```swift
withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
    isExpanded.value.toggle()
}
```

### Theming

```swift
// Access theme colors via environment
VStack { ... }
    .environment(\.colorScheme, .light)
```

### Navigation

```swift
Sidebar(width: 220) {
    SidebarItem(label: "Home", isSelected: true) { /* select */ }
    SidebarItem(label: "Settings") { /* select */ }
} detail: {
    Text("Detail content")
}
```

### Platform Integration

```swift
// Clipboard
let text = RavenCore.clipboardGet()
RavenCore.clipboardSet("copied!")

// File dialogs
if let path = RavenCore.openFileDialog(title: "Open", filter: "*.swift") {
    print("Selected: \(path)")
}
```

---

## Documentation

- **[Getting Started](Docs/GETTING_STARTED.md)** — Build your first Raven app
- **[API Reference](Docs/API_REFERENCE.md)** — Complete type reference
- **[Architecture](Docs/ARCHITECTURE.md)** — How Raven works internally
- **[Framework Document](Docs/RAVEN_FRAMEWORK_DOCUMENT.md)** — Vision & design philosophy

---

## Philosophy

1. **Native first** — No web views, no JavaScript. Swift + Vulkan all the way down.
2. **Declarative** — Describe what your UI looks like, not how to draw it.
3. **Fast** — GPU-accelerated rendering with minimal CPU overhead.
4. **Cross-platform** — One codebase for Windows, macOS, and Linux.
5. **Developer joy** — If you know SwiftUI, you already know Raven.

---

## License

Raven is proprietary software.
