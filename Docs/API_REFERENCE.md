# Raven API Reference

Complete reference for all public types in the Raven framework.

---

## Core Protocols

### `View`
The base protocol for all UI elements.

```swift
protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
```

Every component implements `View`. Primitive views (Text, Button, Spacer, Stacks) have `Body = Never` and are handled directly by the framework.

### `ViewModifier`
Protocol for modifiers that transform layout nodes.

```swift
protocol ViewModifier {
    func apply(to node: LayoutNode)
}
```

---

## Components

### `Text`
Displays a string using the embedded bitmap font.

```swift
Text("Hello, World!")
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | The text to display |

**Supported Modifiers:** `.foreground()`, `.padding()`, `.background()`, `.frame()`

---

### `Button`
A clickable button with a text label.

```swift
Button("Click Me") {
    print("Pressed!")
}
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | Button text |
| `action` | `@Sendable () -> Void` | Closure called on press |

**Default styling:** Blue (`.primary`) background, white text, 6px corner radius, 10×20 padding.

---

### `Spacer`
Flexible space that expands to fill available space in stacks.

```swift
VStack {
    Text("Top")
    Spacer()
    Text("Bottom")
}
```

---

### `VStack`
Arranges children vertically (top to bottom).

```swift
VStack(alignment: .center, spacing: 16) {
    Text("First")
    Text("Second")
    Text("Third")
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alignment` | `HorizontalAlignment` | `.center` | `.leading`, `.center`, or `.trailing` |
| `spacing` | `Float` | `8` | Space between children (pixels) |

---

### `HStack`
Arranges children horizontally (left to right).

```swift
HStack(alignment: .center, spacing: 12) {
    Text("Left")
    Text("Right")
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alignment` | `VerticalAlignment` | `.center` | `.top`, `.center`, or `.bottom` |
| `spacing` | `Float` | `8` | Space between children (pixels) |

---

### `ZStack`
Overlays children on top of each other (back to front).

```swift
ZStack {
    Text("Background")
        .frame(width: 200, height: 100)
        .background(.red)
    Text("Foreground")
}
```

---

## View Modifiers

All modifiers return `ModifiedView<Self, Modifier>` and can be chained:

```swift
Text("Styled")
    .padding(16)
    .background(.blue)
    .foreground(.white)
    .frame(width: 200, height: 50)
    .cornerRadius(8)
```

### `.padding(_:)`
```swift
func padding(_ value: Float) -> ModifiedView<Self, PaddingModifier>
func padding(top: Float, leading: Float, bottom: Float, trailing: Float) -> ModifiedView<Self, PaddingModifier>
func padding(_ insets: EdgeInsets) -> ModifiedView<Self, PaddingModifier>
```

### `.background(_:)`
```swift
func background(_ color: Color) -> ModifiedView<Self, BackgroundModifier>
```

### `.foreground(_:)`
```swift
func foreground(_ color: Color) -> ModifiedView<Self, ForegroundModifier>
```

### `.frame(width:height:)`
```swift
func frame(width: Float? = nil, height: Float? = nil) -> ModifiedView<Self, FrameModifier>
```

### `.cornerRadius(_:)`
```swift
func cornerRadius(_ radius: Float) -> ModifiedView<Self, CornerRadiusModifier>
```

---

## Types

### `Color`
RGBA color with float components (0.0–1.0).

```swift
Color(0.35, 0.55, 0.95)       // RGB, alpha defaults to 1.0
Color(0.35, 0.55, 0.95, 0.5)  // RGBA
```

**Named colors:**

| Name | RGB | Use |
|------|-----|-----|
| `.primary` | `(0.35, 0.55, 0.95)` | Actions, links |
| `.background` | `(0.08, 0.10, 0.14)` | App background |
| `.surface` | `(0.14, 0.16, 0.20)` | Cards, containers |
| `.surfaceLight` | `(0.20, 0.22, 0.28)` | Elevated surfaces |
| `.text` | `(0.92, 0.92, 0.94)` | Primary text |
| `.textSecondary` | `(0.60, 0.62, 0.66)` | Secondary text |
| `.red` | `(0.92, 0.26, 0.21)` | Error, destructive |
| `.green` | `(0.18, 0.80, 0.44)` | Success |
| `.blue` | `(0.20, 0.40, 0.92)` | Info |
| `.yellow` | `(0.96, 0.76, 0.18)` | Warning |
| `.orange` | `(0.96, 0.52, 0.10)` | Accent |
| `.purple` | `(0.61, 0.32, 0.88)` | Accent |
| `.white`, `.black`, `.clear`, `.gray`, `.darkGray` | Standard | |

### `EdgeInsets`
```swift
EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
EdgeInsets(16)  // All sides equal
```

### `HorizontalAlignment`
`.leading` | `.center` | `.trailing`

### `VerticalAlignment`
`.top` | `.center` | `.bottom`

---

## Entry Point

### `RavenApp`
The main application container.

```swift
let app = RavenApp(title: "My App", width: 960, height: 640) {
    // Your view hierarchy here
}
app.run()
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `String` | `"Raven App"` | Window title |
| `width` | `Int` | `960` | Initial window width |
| `height` | `Int` | `640` | Initial window height |
| `content` | `@ViewBuilder () -> Content` | — | Root view |

---

## `@ViewBuilder`
Result builder that enables the `{ }` block syntax. Supports up to 6 child views, optionals (`if`), and conditionals (`if-else`).

```swift
@ViewBuilder var body: some View {
    Text("Always visible")

    if showDetails {
        Text("Conditionally visible")
    }
}
```
