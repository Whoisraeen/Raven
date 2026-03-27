<div align="center">

# 🪶 Raven

**A Swift-native cross-platform UI framework**

Build beautiful, performant desktop applications with a SwiftUI-inspired declarative API —
powered by Vulkan, no Electron, no web views.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Vulkan](https://img.shields.io/badge/Vulkan-1.0-red.svg)](https://vulkan.lunarg.com)
[![Platform](https://img.shields.io/badge/Platform-Windows%20|%20macOS%20|%20Linux-blue.svg)](.)
[![License](https://img.shields.io/badge/License-Proprietary-lightgrey.svg)](.)

</div>

---

## What is Raven?

Raven is a **native UI framework** that lets you build cross-platform desktop apps in pure Swift. Instead of wrapping a web browser (like Electron/Tauri), Raven renders directly via Vulkan — giving you native performance, tiny binaries, and pixel-perfect control.

```swift
import Raven

let app = RavenApp(title: "My App") {
    VStack(spacing: 16) {
        Text("Hello, Raven!")
            .foreground(.white)

        HStack(spacing: 12) {
            Text("Fast").padding(8).background(.red)
            Text("Native").padding(8).background(.green)
            Text("Beautiful").padding(8).background(.blue)
        }

        Button("Get Started") {
            print("Let's go!")
        }
    }
    .padding(32)
    .background(.surface)
}

app.run()
```

**Zero Vulkan code. Zero pixel coordinates. Zero GPU knowledge.**

---

## Features

| Feature | Status |
|---------|--------|
| SwiftUI-style declarative API | ✅ |
| `VStack` / `HStack` / `ZStack` layouts | ✅ |
| `Text`, `Button`, `Spacer` components | ✅ |
| View modifiers (`.padding`, `.background`, `.foreground`, `.frame`) | ✅ |
| Vulkan-powered rendering | ✅ |
| SDF text rendering | ✅ |
| SDL3 window management + input | ✅ |
| `@State` / `@Binding` state management | 🔜 |
| Animation system | 🔜 |
| macOS (MoltenVK) + Linux | 🔜 |
| Hot reload | 🔜 |

---

## Quick Start

### Prerequisites

| Dependency | Version | Notes |
|-----------|---------|-------|
| [Swift](https://swift.org/download) | 6.0+ | Windows/macOS/Linux |
| [Vulkan SDK](https://vulkan.lunarg.com/sdk/home) | 1.0+ | For GPU rendering |
| [SDL3](https://github.com/libsdl-org/SDL) | 3.4+ | Included in `vendor/` |

### Build & Run

```powershell
# Clone
git clone https://github.com/Whoisraeen/Raven.git
cd Raven

# Compile shaders (requires Vulkan SDK)
powershell -File Bootstrap/WindowsSDLHello/Shaders/compile_shaders.ps1

# Build
swift build

# Run the demo
swift run RavenDemo
```

---

## Project Structure

```
Raven/
├── Package.swift                ← SPM package definition
├── Sources/
│   ├── Raven/                   ← The framework (import Raven)
│   │   ├── View.swift           ← View protocol & ViewBuilder
│   │   ├── LayoutEngine.swift   ← Two-pass layout system
│   │   ├── Components/          ← Text, Button, Spacer, Stacks
│   │   ├── Renderer/            ← Vulkan internals (hidden from devs)
│   │   └── RavenApp.swift       ← App entry point
│   └── RavenDemo/               ← Example app
├── Bootstrap/                   ← Original Vulkan bootstrap (reference)
├── Docs/                        ← Developer documentation
└── vendor/SDL3/                 ← SDL3 dependency
```

---

## Documentation

- **[Getting Started](Docs/GETTING_STARTED.md)** — Build your first Raven app
- **[API Reference](Docs/API_REFERENCE.md)** — Complete reference for all types
- **[Architecture](Docs/ARCHITECTURE.md)** — How Raven works internally
- **[Development Checklist](Docs/Development%20Checklist.md)** — Roadmap progress
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

Raven is proprietary software. See [LICENSE](LICENSE) for details.
