# Raven Architecture

How Raven works under the hood — for framework contributors and curious developers.

---

## Pipeline Overview

```
┌─────────────────┐
│  Developer Code  │  VStack { Text("Hi"); Button("Go") { ... } }
└────────┬────────┘
         │ @ViewBuilder + result builder
         ▼
┌─────────────────┐
│    View Tree     │  VStack<TupleView2<Text, Button>>
└────────┬────────┘
         │ ViewResolver.resolve()
         ▼
┌─────────────────┐
│  LayoutNode Tree │  Concrete tree with properties, IDs, handlers
└────────┬────────┘
         │ LayoutEngine.resolve()
         ▼
┌─────────────────┐
│ Positioned Nodes │  Each node has (x, y, width, height)
└────────┬────────┘
         │ RenderCollector.collect()
         ▼
┌─────────────────────────────────┐
│ Quads + TextCmds + ImageCmds    │  Flat arrays with clip rects
└────────┬────────────────────────┘
         │ VulkanRenderer.drawFrame()
         ▼
┌─────────────────┐
│     Pixels       │  On-screen via Vulkan swapchain
└─────────────────┘
```

---

## Module Map

| Module | Files | Responsibility |
|--------|-------|----------------|
| **Core** | `Raven.swift`, `RavenApp.swift`, `Types.swift` | App lifecycle, SDL event loop, core types |
| **View System** | `View.swift`, `ViewBuilder.swift`, `ViewModifiers.swift`, `ViewResolver.swift` | Declarative DSL, parameter packs, modifier chains, view-to-node resolution |
| **State** | `State.swift` | `@State`, `@Binding`, `StateVar`, `@Published`, `StateTracker` with dirty-path tracking |
| **Layout** | `LayoutEngine.swift`, `LayoutNode.swift` | Two-pass layout (measure + position), intrinsic size caching |
| **Animation** | `Animation.swift` | `AnimationEngine`, spring/easing physics, `withAnimation`, callback animations |
| **Environment** | `Environment.swift` | `@Environment`, `EnvironmentKey`, `EnvironmentValues`, scoped propagation |
| **Theme** | `Theme.swift` | 20 semantic color tokens, light/dark presets, `ThemeKey` |
| **Components** | `Components/` | `Text`, `Button`, `Spacer`, `Image`, `TextField`, `ScrollView`, `Stacks`, `FlowStack`, `ForEach`, `Divider`, `List`, `NavigationStack`, `Sidebar`, `Sheet` |
| **Renderer** | `Renderer/` | Vulkan quad/text/image pipelines, font atlas, buffer management |
| **Render Bridge** | `RenderCollector.swift` | Walks LayoutNode tree, produces flat draw command arrays |
| **Events** | `EventDispatcher.swift` | Hit testing (respects hidden/disabled), click dispatch, focus |
| **Accessibility** | `Accessibility.swift`, `AccessibilityCollector.swift` | Semantic roles, labels, tree collection |
| **Focus** | `FocusManager.swift` | TextField focus tracking |
| **Platform** | `Platform/RavenCore.swift` | Swift wrapper for Rust FFI |
| **Rust Core** | `rust/raven-core/` | Clipboard, file dialogs, platform detection via C FFI |
| **C Modules** | `CRavenCore/`, `CSDL3/`, `CVulkan/` | Module maps for FFI, SDL3, Vulkan headers |
| **CLI** | `cli/` | Node.js CLI: build, run, dev, bundle, init, clean, doctor |

---

## View Resolution

### ViewBuilder and Type System

Raven uses Swift's `@resultBuilder` to transform declarative blocks into concrete types:

```swift
VStack {
    Text("A")    // → TupleView2<Text, Button>
    Button("B") { }
}
```

The `ViewBuilder` generates `TupleView2` through `TupleView6` for blocks with 2-6 children, plus `ParameterPackView` for unlimited children via Swift parameter packs.

### ViewResolver

Bridges the generic `View` hierarchy to concrete `LayoutNode` trees using type erasure protocols:

```
Developer's View struct
        │
        ▼
ViewResolver.resolve()
  - Mirror reflection to inject @Environment values
  - Type-check against known primitives (Text, Button, etc.)
  - If primitive: create LayoutNode with properties + handlers
  - If composite: recurse into view.body
  - If ModifiedView: resolve content, apply modifier to node
  - If TupleView: resolve each child with indexed path
  - If ConditionalView: resolve active branch
        │
        ▼
LayoutNode tree (IDs, properties, event handlers)
```

Key pattern — type erasure via protocols:
```swift
if let tv2 = view as? AnyTupleView2 {
    children = tv2.resolveChildren()
}
```

---

## Layout Engine

Two-pass algorithm:

### Pass 1: Intrinsic Size (bottom-up)
Each `LayoutNode` calculates its ideal size based on:
- Text content → `FontManager.measureText()` with `maxWidth` for word wrap
- Image → texture dimensions
- Children → recursive measurement
- Constraints → `.frame(width:height:)` overrides
- Caching → `cachedIntrinsicWidth`/`cachedIntrinsicHeight` cleared on state change

### Pass 2: Position Assignment (top-down)
Parent nodes assign positions to children:
- **VStack**: top-to-bottom, flexible children (Spacer) split remaining height equally
- **HStack**: left-to-right, same flex distribution horizontally, optional baseline alignment
- **ZStack**: all children centered at the same origin
- **FlowStack**: left-to-right with line wrapping (CSS flex-wrap)
- **ScrollView**: content origin offset by scroll position

### Spacing and Alignment
- `VStack(alignment: .leading/.center/.trailing, spacing: Float)`
- `HStack(alignment: .top/.center/.bottom, spacing: Float)`
- Alignment is applied after flex distribution

---

## Render Pipeline

### RenderCollector

Walks the positioned LayoutNode tree and produces three flat arrays:
- `[Quad]` — colored rectangles (backgrounds, borders, shadows)
- `[TextDrawCommand]` — text with position, color, fontSize, maxWidth, clipRect
- `[ImageDrawCommand]` — textured quads with clipRect

**Clip rect propagation**: ScrollView nodes create a `ClipRect` from their bounds. This clip rect is intersected with the parent's clip rect and passed to all descendants. The renderer uses `vkCmdSetScissor` per batch to enforce clipping.

**Shadow rendering**: Shadow quads are emitted before background quads for correct layering.

### Vulkan Renderer

Split across multiple files:

| File | Responsibility |
|------|---------------|
| `VulkanRenderer.swift` | Instance, device, swapchain, command recording, frame sync, clip-rect batching |
| `VulkanPipeline.swift` | Render pass, graphics pipelines, framebuffers |
| `VulkanHelpers.swift` | `Quad`/`QuadVertex`/`ClipRect` types, `VulkanBuffer`, SPIR-V loader |
| `TextRenderer.swift` | Font atlas texture, text pipeline, glyph vertex generation with word wrap |
| `ImageRenderer.swift` | Image texture loading (stb_image), image pipeline |
| `FontManager.swift` | TrueType font loading (stb_truetype), glyph rasterization, atlas management |
| `FontAtlas.swift` | Embedded 8x16 bitmap font (fallback) |

**Rendering happens in a single render pass with three sub-draws:**
1. Bind quad pipeline → draw background/border/shadow quads (batched by clip rect)
2. Bind text pipeline → draw text glyph quads (with font atlas texture, batched by clip rect)
3. Bind image pipeline → draw image quads (per-image descriptor set)

**Vertex buffer strategy**: Geometric 2x growth — `max(needed, 1024) * 2` — avoids per-frame reallocation.

### Shader Architecture

| Shader | Purpose | Vertex Format |
|--------|---------|--------------|
| `quad.vert/frag` | Flat-colored rectangles | `vec2 pos` + `vec4 color` (24 bytes) |
| `text.vert/frag` | SDF text rendering | `vec2 pos` + `vec2 uv` + `vec4 color` (32 bytes) |
| `image.vert/frag` | Textured quads | `vec2 pos` + `vec2 uv` (16 bytes) |

All shaders use a push constant (`vec2 viewportSize`) to convert pixel coordinates to clip space.

The text fragment shader uses `smoothstep` for crisp edges at any scale.

---

## State Management

### State Flow

```
User interaction (click, type, scroll)
        │
        ▼
Event handler mutates StateVar / @State
        │
        ▼
StateTracker.markDirty(path:)
  - Sets dirty flag + records changed path
        │
        ▼
Main loop: StateTracker.checkAndClear()
  - Returns dirty paths, resets flag
        │
        ▼
Snapshot previous positions (for animation)
        │
        ▼
Full view tree rebuild
  - contentBuilder() re-evaluated
  - ViewResolver resolves entire tree
  - LayoutEngine assigns positions/sizes
        │
        ▼
RenderCollector produces new draw commands → Renderer draws frame
```

### State Types

| Type | Usage | Scope |
|------|-------|-------|
| `StateVar<T>` | Top-level reactive state | File/module scope |
| `@State` | View-local reactive state | Inside a View struct |
| `@Binding` | Two-way reference to parent state | Passed down the view tree |
| `@Published` | Property wrapper for ObservableObject | Class properties |
| `StateTracker` | Singleton that tracks dirty paths | Framework-internal |

### Lifecycle Callbacks

`onAppear` and `onDisappear` are tracked via node ID diffing:
- Each frame, `RavenApp` collects all node IDs from the current tree
- New IDs (not in previous frame) trigger `onAppear`
- Removed IDs (in previous frame, not current) trigger `onDisappear`

---

## Animation System

```
withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
    someState.value = newValue
}
        │
        ▼
AnimationEngine.currentAnimation = .spring(...)
        │
        ▼
State setter → markDirty() → view tree rebuilds
        │
        ▼
LayoutNode.x/y/opacity didSet checks AnimationEngine.currentAnimation
  - If set: creates AnimationInstance (weak node ref + property + start/end + curve)
  - Added to AnimationEngine.activeAnimations
        │
        ▼
AnimationEngine.currentAnimation cleared
        │
        ▼
Each frame: AnimationEngine.tick(deltaTime:)
  - Updates elapsed time on each instance
  - Interpolates via curve (spring/easeIn/easeOut/easeInOut/linear)
  - Applies to node property
  - Marks dirty to trigger re-render
  - Removes completed animations
  - AnimationInstance holds weak ref to node (no retain cycle)
```

---

## Platform Layer (Rust FFI)

### Architecture

```
Swift App Code
      │ calls
      ▼
RavenCore.swift (Swift enum, thin wrapper)
      │ calls C functions
      ▼
CRavenCore module map → raven_core.h
      │ links
      ▼
libraven_core.a (Rust static library)
  ├── lib.rs      — FFI exports, error handling
  ├── platform.rs — OS detection (#[cfg(target_os)])
  ├── clipboard.rs — Win32 API / pbcopy / xclip
  └── file_dialog.rs — PowerShell / osascript / zenity
```

### Memory Management

- Rust functions returning strings allocate via `CString::into_raw()`
- Swift calls `raven_core_free_string()` to deallocate
- `raven_core_last_error()` returns a pointer to thread-local storage (valid until next FFI call)
- Static strings (`raven_core_version()`, `raven_core_platform_name()`) point to `c""` literals — no free needed

### Error Handling

Thread-local `LAST_ERROR` stores the most recent error message. After any FFI call that might fail, Swift can check `RavenCore.lastError`.

---

## Event Dispatch

`EventDispatcher` handles SDL events:

1. **Hit testing**: Recursive walk from root, checking if `(mouseX, mouseY)` falls within node bounds. Skips hidden and disabled nodes.
2. **Click dispatch**: Calls the node's `onClick` handler (set by `Button` or `.onTapGesture`).
3. **Focus**: `FocusManager` tracks which `TextField` is active. Click on a TextField gives it focus; click elsewhere removes focus.
4. **Scroll**: Mouse wheel events dispatched to the deepest ScrollView under the cursor.
5. **Keyboard**: Key events routed to the focused TextField.

---

## Threading Model

All framework singletons (`StateTracker`, `AnimationEngine`, `EnvironmentStore`, `FontManager`, `FocusManager`) are main-thread-only. The SDL event loop runs on the main thread, and all state mutations and rendering happen synchronously within that loop.

If async work is needed in the future, proper isolation (actors or dispatch queues) will need to be added.

---

## Adding New Components

To add a new primitive component:

1. Create `Sources/Raven/Components/MyComponent.swift`
2. Implement `View` with `Body = Never`
3. Add resolution logic in `ViewResolver.resolvePrimitive()` — create a LayoutNode, set properties
4. The layout engine handles positioning automatically
5. RenderCollector emits the appropriate draw commands based on node properties

To add a new modifier:

1. Add a `struct MyModifier: ViewModifier` in `ViewModifiers.swift`
2. Implement `func apply(to node: LayoutNode)` — set the relevant LayoutNode property
3. Add the extension method on `View` — return `ModifiedView<Self, MyModifier>`
