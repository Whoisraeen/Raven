# Getting Started with Raven

Build your first Raven app in under 5 minutes.

---

## Prerequisites

Before you begin, install:

1. **Swift 6.0+** — [swift.org/download](https://swift.org/download)
2. **Vulkan SDK** — [vulkan.lunarg.com](https://vulkan.lunarg.com/sdk/home)
3. **SDL3** — Already included in `vendor/SDL3/`

Verify Swift is installed:
```powershell
swift --version
# Swift version 6.x.x
```

Verify Vulkan SDK:
```powershell
glslangValidator --version
# Should print version info
```

---

## 1. Clone and Build

```powershell
git clone https://github.com/your-org/Raven.git
cd Raven

# Compile the GLSL shaders to SPIR-V
powershell -File Bootstrap/WindowsSDLHello/Shaders/compile_shaders.ps1

# Build the framework and demo
swift build
```

---

## 2. Run the Demo

```powershell
swift run RavenDemo
```

You should see a window with:
- A title bar ("Hello from Raven!")
- Three colored boxes (Red, Green, Blue) in a row
- A "Click Me" button at the bottom

---

## 3. Create Your Own App

Create a new file `Sources/RavenDemo/main.swift` (or replace the existing one):

```swift
import Raven

let app = RavenApp(title: "My First App", width: 800, height: 600) {
    VStack(spacing: 20) {
        Text("Welcome to Raven!")
            .foreground(.white)
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
```powershell
swift build && swift run RavenDemo
```

---

## 4. Core Concepts

### Views
Everything is a `View`. Views declare their content via a `body` property:

```swift
struct MyView: View {
    var body: some View {
        Text("Hello!")
    }
}
```

### Stacks
Arrange views with `VStack` (vertical), `HStack` (horizontal), or `ZStack` (layered):

```swift
VStack(spacing: 16) {
    Text("Top")
    Text("Middle")
    Text("Bottom")
}
```

### Modifiers
Chain modifiers to customize views:

```swift
Text("Styled")
    .padding(16)           // Add padding
    .background(.blue)     // Blue background
    .foreground(.white)    // White text
    .frame(width: 200)     // Fixed width
```

### Spacer
Use `Spacer()` to push content:

```swift
VStack {
    Text("Top")
    Spacer()       // Fills available space
    Text("Bottom") // Pushed to bottom
}
```

---

## 5. Available Components

| Component | Usage | Description |
|-----------|-------|-------------|
| `Text("...")` | Display text | Renders text using the embedded font |
| `Button("...", action: {})` | Clickable button | Label + action closure |
| `Spacer()` | Flexible space | Expands to fill available space |
| `VStack { }` | Vertical layout | Stacks children top-to-bottom |
| `HStack { }` | Horizontal layout | Stacks children left-to-right |
| `ZStack { }` | Layered layout | Stacks children on top of each other |

---

## 6. Available Modifiers

| Modifier | Description |
|----------|-------------|
| `.padding(Float)` | Add equal padding on all sides |
| `.padding(top:leading:bottom:trailing:)` | Add specific edge padding |
| `.background(Color)` | Set background color |
| `.foreground(Color)` | Set text/foreground color |
| `.frame(width:height:)` | Set fixed dimensions |
| `.cornerRadius(Float)` | Round corners |

---

## 7. Colors

Raven includes a curated color palette:

| Color | Value | Description |
|-------|-------|-------------|
| `.primary` | Blue | Primary action color |
| `.background` | Near-black | App background |
| `.surface` | Dark gray | Card/container background |
| `.surfaceLight` | Medium gray | Elevated surface |
| `.text` | Near-white | Primary text |
| `.textSecondary` | Gray | Secondary text |
| `.red`, `.green`, `.blue` | Standard | UI accent colors |
| `.white`, `.black`, `.clear` | Standard | Basic colors |
| `Color(r, g, b, a)` | Custom | Any RGBA color (0-1 range) |

---

## Next Steps

- Read the [API Reference](API_REFERENCE.md) for complete type documentation
- Explore the [Architecture](ARCHITECTURE.md) to understand how Raven works
- Check the [Development Checklist](Development%20Checklist.md) for upcoming features
