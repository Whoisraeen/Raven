# Raven Architecture

How Raven works under the hood — for framework contributors and curious developers.

---

## Pipeline Overview

```
┌─────────────────┐
│  Developer Code  │  VStack { Text("Hi") }
└────────┬────────┘
         │ ViewBuilder
         ▼
┌─────────────────┐
│    View Tree     │  VStack<TupleView2<Text, Button>>
└────────┬────────┘
         │ ViewResolver.resolve()
         ▼
┌─────────────────┐
│  LayoutNode Tree │  Tree of positioned nodes with properties
└────────┬────────┘
         │ LayoutEngine.resolve()
         ▼
┌─────────────────┐
│ Positioned Nodes │  Each node has (x, y, width, height)
└────────┬────────┘
         │ RenderCollector.collect()
         ▼
┌──────────────────────────┐
│  Quads + TextDrawCommands │  Flat arrays ready for GPU
└────────┬─────────────────┘
         │ VulkanRenderer.drawFrame()
         ▼
┌─────────────────┐
│     Pixels       │  On-screen via Vulkan swapchain
└─────────────────┘
```

---

## Key Modules

### 1. View Protocol & ViewBuilder (`View.swift`, `ViewBuilder.swift`)

The `View` protocol uses Swift's associated types and the `@resultBuilder` pattern to enable declarative syntax. The `ViewBuilder` generates `TupleView2`–`TupleView6` types to hold 2–6 children within a `@ViewBuilder` block.

**Type flow:** `VStack { Text("A"); Text("B") }` produces `VStack` containing a `TupleView2<Text, Text>`.

### 2. ViewResolver (`ViewResolver.swift`)

Bridges the generic `View` type hierarchy to the concrete `LayoutNode` tree. Uses **type erasure protocols** (`AnyTupleView2`, `AnyModifiedView`, etc.) to inspect generic types at runtime via `as?` casts. This avoids the need for `AnyView` type erasure.

**Key pattern:**
```swift
if let tv2 = view as? AnyTupleView2 {
    children = tv2.resolveChildren()
}
```

### 3. Layout Engine (`LayoutEngine.swift`)

Two-pass layout algorithm:

1. **Intrinsic Size** (bottom-up): Each `LayoutNode` calculates its ideal size based on content, children, and constraints.
2. **Position Assignment** (top-down): Parent nodes assign positions to children based on stack axis, spacing, alignment, and available space.

**Stack layouts:**
- **VStack**: Distributes children vertically. Flexible children (`Spacer`) split remaining height equally.
- **HStack**: Same, but horizontally.
- **ZStack**: All children centered at the same origin.

### 4. Render Collector (`RenderCollector.swift`)

Walks the positioned `LayoutNode` tree and produces two flat arrays:
- `[Quad]` — Background colored rectangles
- `[TextDrawCommand]` — Text strings with position and color

### 5. Vulkan Renderer (`Renderer/`)

The renderer is split into three files:

| File | Responsibility |
|------|---------------|
| `VulkanHelpers.swift` | Constants, `Quad`/`QuadVertex` types, buffer management, SPIR-V loading |
| `VulkanPipeline.swift` | Render pass, quad graphics pipeline, image views, framebuffers |
| `VulkanRenderer.swift` | Instance, device, swapchain, command recording, frame sync |
| `TextRenderer.swift` | Font atlas texture, text graphics pipeline, glyph vertex generation |
| `FontAtlas.swift` | Embedded 8×16 bitmap font, UV calculation |

**Rendering happens in a single render pass with two sub-draws:**
1. Bind quad pipeline → draw background quads
2. Bind text pipeline → draw text glyph quads (with font atlas texture)

### 6. RavenApp (`RavenApp.swift`)

Ties everything together:
```
SDL_Init → SDL_CreateWindow → VulkanRenderer()
                                    ↓
                            Event loop:
                            while running {
                                SDL_PollEvent()
                                ViewResolver.resolve(content)
                                LayoutEngine.resolve(root, viewport)
                                RenderCollector.collect(root)
                                renderer.drawFrame(quads, text)
                            }
```

---

## Shader Architecture

| Shader | Purpose | Vertex Format |
|--------|---------|--------------|
| `quad.vert/frag` | Flat-colored rectangles | `vec2 pos` + `vec4 color` (24 bytes) |
| `text.vert/frag` | SDF-style text | `vec2 pos` + `vec2 uv` + `vec4 color` (32 bytes) |

Both shaders use a **push constant** (`vec2 viewportSize`) to convert pixel coordinates to clip space: `clip = (pixel / viewport) * 2.0 - 1.0`.

The text fragment shader uses `smoothstep(0.3, 0.7, texel)` for crisp edges at any scale.

---

## Text Rendering

The font atlas is a simple 8×16 pixel bitmap (VGA-style) covering ASCII 32-126 (95 printable characters). It's stored as a `[UInt8]` constant in `FontAtlas.swift` and uploaded to a GPU texture at startup.

**Atlas layout:** 16 columns × 6 rows = 128×96 pixel R8 texture.

Each character in a `TextDrawCommand` becomes 6 vertices (2 triangles) with UV coordinates mapping into the atlas.

**Upgrade path:** The architecture is designed so a proper MSDF atlas (e.g., from msdf-atlas-gen) can replace the bitmap atlas without changing any framework code — only `FontAtlas.swift` and the SPIR-V shaders need to change.

---

## Adding New Components

To add a new primitive component:

1. Create `Sources/Raven/Components/MyComponent.swift`
2. Implement `View` with `Body = Never`
3. Add any state properties to `LayoutNode`
4. Add resolution logic in `ViewResolver.resolvePrimitive()`
5. Add event handling in `EventDispatcher` if interactive
6. Add accessibility role in `Accessibility.swift`
7. The layout engine handles positioning automatically

---

## Theme System (`Theme.swift`)

Centralized design tokens that affect all component rendering:

```
Theme.current ──► ThemeColors    (primary, surface, text, ...)
               ──► ThemeTypography (defaultFontSize, titleFontSize, ...)
               ──► ThemeSpacing   (xxs=2, xs=4, sm=8, md=12, lg=16, ...)
               ──► ThemeShapes    (sm=4, md=8, lg=12, ...)
```

Ships with `.dark` (default) and `.light` presets. Components read from `Theme.current.colors.*` in their ViewResolver methods.

---

## Logging System (`Logger.swift`)

Structured logging with severity levels:

| Level | Usage |
|-------|-------|
| `.debug` | Detailed internal state (filtered in release) |
| `.info` | Normal operation events |
| `.warning` | Degraded behavior, non-critical |
| `.error` | Operation failures |
| `.critical` | Fatal, unrecoverable |

Uses `#fileID` + `#line` for source location. Auto-filters by build mode. Supports custom handlers via `RavenLogger.customHandler`.

Error types: `FontError`, `RendererError`, `PlatformError`.

---

## Platform Layer (`Platform/`, `rust/raven-core/`)

Cross-platform OS service access via Rust FFI:

```
Swift (PlatformAPI.swift: RavenPlatform enum)
  ↓ C FFI
C Header (raven_core.h)
  ↓ extern "C"
Rust (platform_api.rs: #[cfg(target_os)] implementations)
  ↓
Windows: PowerShell / WinAPI
macOS:   pbcopy / osascript
Linux:   xclip / zenity / notify-send
```

Services: clipboard (get/set text), file dialogs (open/save), OS notifications.

---

## Navigation Components

| Component | Architecture |
|-----------|-------------|
| **TabView** | VStack with content area (swapped by tab index) + bottom HStack tab bar. Tab clicks update `Binding<Int>`. |
| **NavigationView** | VStack with HStack nav bar (title) + divider + content. |
| **Sheet** | Applied via `SheetModifier`. When `Binding<Bool>` is true, a dimmed overlay + centered content renders on top. |
| **Divider** | Single LayoutNode with `fixedHeight: 1` and `divider` background color. |
