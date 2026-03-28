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

Every component implements `View`. Primitive views (Text, Button, Spacer, Stacks, etc.) have `Body = Never` and are handled directly by the framework.

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

Displays a string using TrueType font rendering (stb_truetype). Supports multi-line text and word wrapping.

```swift
Text("Hello, World!")
Text("Long paragraph here...")
    .foreground(.text)
    .font(size: 18)
    .textWrap(maxWidth: 300)
```

| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | The text to display |

Supports `\n` newlines and automatic word wrapping via `.textWrap(maxWidth:)`.

---

### `Button`

A clickable button with a text label.

```swift
Button("Click Me") {
    print("Pressed!")
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | Button text |
| `action` | `@Sendable () -> Void` | Closure called on press |

Default styling: `.primary` background, white text, 6px corner radius, 10x20 padding. Hover state darkens the background.

---

### `Spacer`

Flexible space that expands to fill available space in stacks.

```swift
VStack {
    Text("Top")
    Spacer()
    Text("Bottom")  // pushed to bottom
}
```

---

### `Image`

Displays a raster image loaded from disk (PNG, JPG, BMP via stb_image).

```swift
Image("Assets/logo.png")
    .frame(width: 200, height: 100)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | File path to the image |

---

### `TextField`

Single-line text input with cursor and focus management.

```swift
let name = StateVar("")

TextField(text: name.binding, placeholder: "Enter name")
    .frame(width: 200)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | `Binding<String>` | Two-way binding to the text value |
| `placeholder` | `String` | Placeholder text shown when empty |

Click to focus. Type to input. Click elsewhere to unfocus.

---

### `VStack`

Arranges children vertically (top to bottom).

```swift
VStack(alignment: .leading, spacing: 16) {
    Text("First")
    Text("Second")
    Text("Third")
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alignment` | `HorizontalAlignment` | `.center` | `.leading`, `.center`, `.trailing` |
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
| `alignment` | `VerticalAlignment` | `.center` | `.top`, `.center`, `.bottom` |
| `spacing` | `Float` | `8` | Space between children (pixels) |

Supports baseline alignment via `.alignToBaseline()` on children.

---

### `ZStack`

Overlays children on top of each other (back to front).

```swift
ZStack {
    Text("Background layer")
        .frame(width: 200, height: 100)
        .background(.red)
    Text("Foreground layer")
}
```

---

### `FlowStack`

Wrapping horizontal layout (like CSS `flex-wrap: wrap`).

```swift
FlowStack(spacing: 8) {
    Text("Tag 1").padding(8).background(.primary)
    Text("Tag 2").padding(8).background(.primary)
    Text("Tag 3").padding(8).background(.primary)
    // wraps to next line when width exceeded
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `spacing` | `Float` | `8` | Space between items |

---

### `ScrollView`

Scrollable container. Supports vertical and horizontal scrolling with mouse wheel. Content is clipped to the scroll view bounds via Vulkan scissor rects.

```swift
ScrollView {
    VStack(spacing: 8) {
        ForEach(0..<100) { i in
            Text("Row \(i)")
                .padding(8)
                .background(.surface)
        }
    }
}
.frame(height: 400)
```

---

### `ForEach`

Iterates a collection or range to produce views.

```swift
// Range
ForEach(0..<5) { index in
    Text("Item \(index)")
}

// Collection
ForEach(items) { item in
    Text(item.name)
}
```

---

### `List`

A scrollable list with automatic dividers between rows. Combines ScrollView + VStack + ForEach.

```swift
List(items) { item in
    Text(item.name)
        .padding(8)
}
```

---

### `Divider`

A visual separator line.

```swift
VStack {
    Text("Above")
    Divider()
    Text("Below")
}
```

---

### `NavigationStack`

Route-based push/pop navigation.

```swift
NavigationStack {
    VStack {
        Button("Go to Detail") {
            NavigationStack.push("detail")
        }
    }
}
```

---

### `Sidebar`

Two-pane layout with a fixed-width sidebar and flexible detail area.

```swift
Sidebar(width: 200) {
    VStack(alignment: .leading, spacing: 0) {
        SidebarItem(label: "Home", isSelected: true) { }
        SidebarItem(label: "Settings", isSelected: false) { }
    }
} detail: {
    Text("Detail content")
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `width` | `Float` | `200` | Sidebar width in pixels |

### `SidebarItem`

A clickable row in a Sidebar.

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | Display text |
| `isSelected` | `Bool` | Whether this item is selected |
| `action` | `() -> Void` | Called on click |

---

### `Sheet`

A modal overlay controlled by a binding.

```swift
let showSheet = StateVar(false)

Sheet(isPresented: showSheet.binding, width: 400, height: 300) {
    VStack {
        Text("Modal Content")
        Button("Close") { showSheet.value = false }
    }
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `isPresented` | `Binding<Bool>` | Controls visibility |
| `width` | `Float` | Sheet width |
| `height` | `Float` | Sheet height |

Clicking the backdrop dismisses the sheet.

---

## View Modifiers

All modifiers return `ModifiedView<Self, Modifier>` and can be chained.

### Layout

```swift
.padding(_ value: Float)
.padding(top: Float, leading: Float, bottom: Float, trailing: Float)
.padding(_ insets: EdgeInsets)
.frame(width: Float?, height: Float?)
.alignToBaseline()
```

### Appearance

```swift
.background(_ color: Color)
.foreground(_ color: Color)
.cornerRadius(_ radius: Float)
.font(size: Float)
.opacity(_ value: Float)                         // 0.0 - 1.0
.border(_ color: Color, width: Float = 1)
.shadow(color: Color, radius: Float, x: Float, y: Float)
.hidden()
.disabled(_ isDisabled: Bool = true)
```

### Text

```swift
.textWrap(maxWidth: Float)
```

### Interaction

```swift
.onTapGesture(_ action: @Sendable () -> Void)
```

### Lifecycle

```swift
.onAppear(_ action: @Sendable () -> Void)
.onDisappear(_ action: @Sendable () -> Void)
```

### Accessibility

```swift
.accessibilityLabel(_ label: String)
.accessibilityValue(_ value: String)
.accessibilityRole(_ role: AccessibilityRole)
.accessibilityHidden(_ hidden: Bool = true)
```

---

## State Management

### `StateVar<T>`

A reactive value container that triggers view re-renders when mutated.

```swift
let count = StateVar(0)

// Read
Text("Count: \(count.value)")

// Write (triggers re-render)
count.value += 1

// Get a binding for two-way connection
TextField(text: count.binding)
```

### `@State`

Property wrapper for view-local state.

```swift
struct Counter: View {
    @State var count = 0

    var body: some View {
        Button("Count: \(count)") {
            count += 1
        }
    }
}
```

### `@Binding`

Two-way reference to state owned by a parent.

```swift
struct ToggleRow: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(isOn ? "ON" : "OFF") {
            isOn.toggle()
        }
    }
}
```

### `@Published`

Property wrapper for use in `ObservableObject` classes.

```swift
class UserModel: ObservableObject {
    @Published var name = ""
    @Published var score = 0
}
```

### `StateTracker`

Framework-internal singleton that tracks which state paths are dirty. Used by `RavenApp` to know when to re-render.

---

## Animation

### `withAnimation`

Wraps state changes to animate the resulting layout changes.

```swift
withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
    position.value = newPosition
}

withAnimation(.easeInOut(duration: 0.5)) {
    opacity.value = 0.0
}
```

### Animation Curves

| Curve | Parameters | Description |
|-------|-----------|-------------|
| `.linear(duration:)` | `Double` | Constant speed |
| `.easeIn(duration:)` | `Double` | Slow start, fast end |
| `.easeOut(duration:)` | `Double` | Fast start, slow end |
| `.easeInOut(duration:)` | `Double` | Slow start and end |
| `.spring(response:dampingFraction:)` | `Double, Double` | Spring physics |

---

## Environment

### `@Environment`

Read values from the environment (theme, layout direction, etc.).

```swift
struct MyView: View {
    @Environment(\.theme) var theme

    var body: some View {
        Text("Hello")
            .foreground(theme.textColor)
    }
}
```

### `EnvironmentKey`

Define custom environment keys:

```swift
struct MyKey: EnvironmentKey {
    static var defaultValue: String { "default" }
}

extension EnvironmentValues {
    var myValue: String {
        get { self[MyKey.self] }
        set { self[MyKey.self] = newValue }
    }
}
```

---

## Theme

### `Theme`

Defines 20 semantic color tokens. Accessed via the environment.

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `background` | Near-white | Near-black | App background |
| `surface` | Light gray | Dark gray | Cards, containers |
| `surfaceLight` | White | Medium gray | Elevated surfaces |
| `text` | Near-black | Near-white | Primary text |
| `textSecondary` | Gray | Gray | Secondary text |
| `primary` | Blue | Blue | Actions, links |
| `primaryHover` | Darker blue | Lighter blue | Hover state |
| `error` | Red | Red | Error indicators |
| `success` | Green | Green | Success indicators |
| `warning` | Yellow | Yellow | Warning indicators |
| `border` | Light gray | Dark gray | Borders |
| `divider` | Light gray | Dark gray | Divider lines |
| `sidebarBg` | Off-white | Near-black | Sidebar background |
| `sidebarItem` | Gray | Gray | Sidebar text |
| `sidebarItemSelected` | Blue | Blue | Selected sidebar item |
| `sheetBackdrop` | Black 30% | Black 50% | Sheet overlay |
| `sheetBackground` | White | Dark gray | Sheet content |
| `inputBackground` | White | Dark gray | TextField background |
| `inputBorder` | Gray | Gray | TextField border |
| `inputFocusBorder` | Blue | Blue | Focused TextField border |

---

## Types

### `Color`

RGBA color with float components (0.0-1.0).

```swift
Color(0.35, 0.55, 0.95)        // RGB, alpha = 1.0
Color(0.35, 0.55, 0.95, 0.5)   // RGBA
```

Named colors: `.primary`, `.background`, `.surface`, `.surfaceLight`, `.text`, `.textSecondary`, `.red`, `.green`, `.blue`, `.yellow`, `.orange`, `.purple`, `.white`, `.black`, `.clear`, `.gray`, `.darkGray`

### `EdgeInsets`

```swift
EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
EdgeInsets(16)  // All sides equal
```

### `HorizontalAlignment`

`.leading` | `.center` | `.trailing`

### `VerticalAlignment`

`.top` | `.center` | `.bottom`

### `ClipRect`

Scissor rectangle for content clipping (used internally by ScrollView).

```swift
ClipRect(x: Float, y: Float, width: Float, height: Float)
ClipRect.none  // No clipping
```

### `AccessibilityRole`

`.button` | `.text` | `.image` | `.textField` | `.group` | `.list` | `.scrollArea` | `.none`

---

## Entry Point

### `RavenApp`

The main application container. Creates an SDL window and runs the Vulkan render loop.

```swift
let app = RavenApp(title: "My App", width: 960, height: 640) {
    // Your view hierarchy
}
app.run()
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `String` | `"Raven App"` | Window title |
| `width` | `Int` | `960` | Initial window width |
| `height` | `Int` | `640` | Initial window height |
| `content` | `@ViewBuilder () -> Content` | required | Root view |

---

## `@ViewBuilder`

Result builder that enables the declarative `{ }` block syntax. Supports:
- Up to 6 children via `TupleView2`-`TupleView6`
- Unlimited children via parameter packs (`TupleView`)
- Optionals (`if let`)
- Conditionals (`if-else`)

```swift
@ViewBuilder var body: some View {
    Text("Always visible")

    if showDetails {
        Text("Conditionally visible")
    }
}
```

---

## Platform (RavenCore)

Swift wrapper around the Rust FFI layer.

```swift
enum RavenCore {
    static func initialize()                           // Init the Rust runtime
    static var version: String                         // "0.1.0"
    static var platformName: String                    // "windows" / "macos" / "linux"
    static var osVersion: String                       // e.g. "10.0.26200"
    static var lastError: String?                      // Last FFI error, or nil

    // Clipboard
    static func clipboardGet() -> String?
    static func clipboardSet(_ text: String) -> Bool

    // File Dialogs
    static func openFileDialog(title:filter:) -> String?
    static func saveFileDialog(title:defaultName:) -> String?
    static func selectFolderDialog(title:) -> String?
}
```
