# RAVEN — Project Documentation
**A Swift-Based Cross-Platform Native UI Framework**
**Version 2.0 | March 2026**

---

## 1. The One Sentence Pitch

Raven is a Swift-based cross-platform UI framework that compiles to native code on Windows, macOS, and Linux — with a consistent, pixel-identical UI across all three, no WebView, no Electron, no compromises.

---

## 2. The Problem

Every developer who has tried to build a cross-platform desktop application has hit the same wall. The options are:

- **Electron** — ships a full Chromium instance with every app, idles at 300MB+ RAM, feels wrong on every platform, and is a security liability
- **Tauri** — better than Electron but still renders UI in a WebView, the feel gap is immediately noticeable to any power user
- **Flutter** — Google-controlled, has its own non-native widget system, feels foreign on desktop, primarily mobile-first
- **Qt** — powerful but expensive for commercial use, ugly by default, enterprise feel from 2005, C++ only
- **.NET MAUI** — Windows-biased, half-baked on Mac, non-existent on Linux, Microsoft can deprecate it at any time
- **React Native Desktop** — a mobile framework forced onto desktop, it shows

The result is that professional developers who care about quality are forced to choose between:

**A.** Ship something that works everywhere but feels like garbage everywhere
**B.** Write separate native apps for each platform and maintain three codebases

Nobody has solved this. Raven solves this.

---

## 3. The Solution

Raven is a UI framework where developers write Swift once and ship natively on Windows, macOS, and Linux. The UI renders identically across all three platforms using a custom Vulkan-based rendering pipeline. No WebView. No platform widget mapping. No compromises on feel or performance.

### Core Principles

1. **Swift everywhere** — One language, one codebase, three platforms
2. **Own the renderer** — Raven draws every pixel itself via Vulkan. The UI looks identical on every OS because it doesn't rely on any OS's widget system
3. **Native performance** — Compiles to native machine code on every platform. No runtime overhead, no interpreter, no virtual machine
4. **Developer experience first** — The API feels like SwiftUI. If you know SwiftUI you know Raven within an hour
5. **No hidden dependencies** — No Chromium, no WebKit, no Node. The final app binary is lean and self-contained

---

## 4. Technical Architecture

### The Stack

```
+---------------------------------------------+
|           DEVELOPER'S SWIFT CODE             |
|       (Raven's declarative Swift API)        |
+---------------------------------------------+
|             LAYOUT ENGINE                    |
|     Flexbox-style, written in Swift          |
|   (Sizing, spacing, constraints, caching)    |
+---------------------------------------------+
|          UI COMPONENT LIBRARY                |
|  Text, Button, TextField, ScrollView,        |
|  Stacks, Navigation, Sidebar, Sheet          |
+---------------------------------------------+
|            ANIMATION ENGINE                  |
|   Spring physics, easing curves, layout      |
|   transitions, callback-based interpolation  |
+---------------------------------------------+
|     ENVIRONMENT + THEME + STATE ENGINE       |
|   @State, @Binding, @Environment, themes,    |
|   dirty tracking, path-based identity        |
+---------------------------------------------+
|               RENDERER                       |
|   Vulkan 1.4 — quad, text (SDF), image       |
|   pipelines with per-frame vertex buffers    |
+---------------------------------------------+
|            PLATFORM LAYER                    |
|   SDL3 — window creation, input, events      |
|   Rust FFI — clipboard, file dialogs         |
+---------------------------------------------+
|         SWIFT + RUST FOUNDATION              |
|   Swift — framework API and UI logic         |
|   Rust — platform bridge via C FFI           |
+---------------------------------------------+
```

### Language Responsibilities

**Swift**
- The entire developer-facing API
- Layout engine (two-pass: measure + layout)
- Component library
- State management (@State, @Binding, StateVar, @Published)
- Animation system (spring physics, easing, callback animations)
- Environment and theme system
- View resolution and modifier chains
- Application logic layer

**Rust**
- Platform bridge — clipboard, file dialogs (Win32/osascript/zenity)
- Platform detection and OS version reporting
- C FFI exports consumed by Swift via CRavenCore module

**Why both:**
Swift gives developers a modern, expressive, type-safe API that feels familiar to anyone who has used SwiftUI. Rust handles platform-specific system integration where each OS has completely different APIs. The two languages interoperate cleanly via C FFI with a hand-maintained header.

### Renderer Details

**Primary: Vulkan 1.4**
- Runs natively on Windows and Linux
- Three separate render pipelines: quads (colored rectangles), text (SDF), images (textured quads)
- Per-frame vertex buffer management with dynamic resizing
- Swapchain recreation on window resize

**macOS: MoltenVK** (planned)
- VK_KHR_portability_enumeration and VK_KHR_portability_subset extensions ready in code
- Package.swift has macOS conditional paths

**Window Management and Input: SDL3**
- Handles window creation, destruction, and resizing
- Handles keyboard, mouse, scroll wheel input
- SDL_Vulkan_CreateSurface for Vulkan surface creation

---

## 5. Current Implementation Status

### What Works (Verified, Building, Tested on Windows)

| Module | Status | Notes |
|--------|--------|-------|
| Vulkan renderer (quad/text/image pipelines) | Done | Stable, handles swapchain recreation |
| SDF text rendering (TrueType via stb_truetype) | Done | Single font, single size (16px base) |
| Image rendering (PNG/JPG/BMP via stb_image) | Done | Loaded into Vulkan textures |
| VStack / HStack / ZStack | Done | Full flex layout with alignment |
| FlowStack (flex-wrap) | Done | Horizontal wrapping layout |
| Baseline alignment | Done | HStack children align on text baseline |
| Text, Button, Spacer, Image | Done | Core primitives |
| TextField (text input) | Done | Basic input with focus management |
| ScrollView (vertical/horizontal) | Done | Scroll offset applied in layout engine |
| @State / @Binding / StateVar / @Published | Done | Path-based dirty tracking |
| @Environment / EnvironmentValues | Done | Stack-based scoped propagation |
| Theme system (light/dark, 20 tokens) | Done | Environment-based, components read from theme |
| NavigationStack (push/pop) | Done | Route-based view switching |
| Sidebar (two-pane layout) | Done | Fixed sidebar + flexible detail |
| Sheet (modal overlay) | Done | Binding-controlled with backdrop dismiss |
| Animation (spring, easeIn/Out/InOut, linear) | Done | Property-based + callback-based |
| withAnimation block API | Done | Sets animation context for state changes |
| Layout transition animations | Done | Path-based identity for continuity |
| Intrinsic size caching | Done | Lazy compute, avoids redundant measureText |
| Clipboard (get/set) | Done | Win32 API / pbcopy / xclip via Rust |
| File dialogs (open/save/folder) | Done | PowerShell / osascript / zenity via Rust |
| Raven CLI (build/run/dev/clean) | Done | Bash script + npm package (swift-raven) |
| Accessibility tree collection | Done | Semantic roles, labels, values |
| ViewBuilder with Parameter Packs | Done | Unlimited children via TupleView |

### What Does NOT Work Yet

| Feature | Status | Blocking Issue |
|---------|--------|----------------|
| macOS builds | Not started | MoltenVK integration incomplete |
| Linux builds | Not tested | Package.swift paths need validation |
| Multi-line text / text wrapping | Missing | TextRenderer has no line-wrap logic |
| Font size control | Missing | Hardcoded 16px, no .font() modifier |
| ScrollView content clipping | Missing | No per-element scissor rects in renderer |
| ForEach | Missing | Cannot iterate dynamic collections |
| List component | Missing | No list/table for scrollable item collections |
| Divider | Missing | No visual separator |
| Toggle / Slider / Picker | Missing | No form input components |
| ProgressView | Missing | No progress indicator |
| Alert / Menu / TabView | Missing | No system-level UI patterns |
| opacity / shadow / border modifiers | Missing | LayoutNode has properties but no modifiers |
| onAppear / onDisappear | Missing | No lifecycle callbacks |
| disabled / hidden modifiers | Missing | No interaction state control |
| Keyboard navigation | Missing | Only TextField has focus, no Tab nav |
| Hot reload | Missing | raven dev watches files but does full restart |
| Cross-compilation | Not started | Build only on host platform |
| SVG / vector graphics | Not started | Only raster images supported |

---

## 6. Known Issues and Technical Debt

### Critical (Will break or cause incorrect behavior)

1. **Font atlas UV bug** — FontManager atlas growth recalculates UVs incorrectly (`u0 * Float(atlasWidth / 2) / Float(atlasWidth)` should be `u0 * 0.5`). Glyphs render wrong after atlas resize.

2. **LayoutNode.previousPositions grows unbounded** — Static dictionary never pruned. Every animated node ID persists forever. Memory leak proportional to app lifetime.

3. **Spring physics instability** — Small `response` values (< 0.01) cause huge stiffness, numerical overflow. `dampingFraction > 1.0` causes `sqrt(negative)` = NaN in underdamped branch.

4. **Division by zero in animation** — `easeIn`/`easeOut`/`easeInOut`/`linear` with `duration: 0` causes `elapsed / 0` = NaN.

5. **LayoutNode.intrinsicWidth uses hardcoded fontSize 16.0** — Text measurement ignores the node's actual `fontSize` property, producing wrong intrinsic sizes for non-default font sizes.

6. **`raven init` generates wrong dependency URL** — Creates `https://github.com/raven-ui/raven.git` instead of `https://github.com/Whoisraeen/Raven.git`. Generated projects cannot build.

### High Priority (Significant gaps)

7. **No ScrollView clipping** — Content renders outside scroll bounds. Vulkan scissor rects exist per-frame but not per-element. Nested ScrollViews will overlap.

8. **No multi-line text** — TextRenderer processes characters left-to-right without wrapping. No newline handling. FontManager.measureText doesn't split on `\n`.

9. **Thread safety across all singletons** — `StateTracker.shared`, `AnimationEngine.shared`, `EnvironmentStore.shared`, `FontManager.shared`, `FocusManager.shared` all have mutable state without synchronization. Currently safe because single-threaded, but will break if any async work is introduced.

10. **Vulkan error handling gaps** — Multiple Vulkan calls don't check VkResult: `vkAllocateCommandBuffers`, `vkMapMemory`, `vkGetBufferMemoryRequirements`. Failed allocations produce garbage handles.

11. **Resource leaks in Vulkan setup** — If `vkCreateImage` succeeds but `vkAllocateMemory` fails, the image handle leaks. Same pattern in buffer creation. No cleanup-on-failure paths.

12. **Retain cycles in closures** — Sheet backdrop `onTap` captures Binding that may capture the Sheet view. SidebarItem `onTap` similarly. `AnimationInstance` holds strong LayoutNode reference during animation.

13. **SDL_strdup memory leaks** — `SDL_strdup("main")` in pipeline creation, `SDL_strdup("VK_KHR_portability_subset")` — allocated but never freed.

### Medium Priority (Quality and completeness)

14. **No `ForEach` or `buildArray`** — Cannot render dynamic collections. ViewBuilder only supports static view composition.

15. **Hardcoded component styling** — Button cornerRadius=6, TextField fixedWidth=200, Sheet cornerRadius=12, SidebarItem padding, all baked into ViewResolver rather than configurable via modifiers or theme.

16. **Version scattered across 5 files** — `Cargo.toml`, `cli/package.json`, `raven` script, `raven.js`, and Rust lib all declare "0.1.0" independently. No single source of truth.

17. **Windows-only SDL3/Vulkan paths** — Package.swift hardcodes `vendor/SDL3/SDL3-3.4.2/lib/x64` (no ARM64) and `C:/VulkanSDK/1.4.341.1/` (version-specific). Linux assumes `/usr/lib`.

18. **Per-frame vertex buffer recreation** — Quad, text, and image renderers reallocate vertex buffers when size changes. No growth factor strategy; allocates exact size needed every time.

19. **No pipeline cache** — Vulkan pipelines recreated from scratch on every app launch. No `VkPipelineCache` for startup optimization.

20. **Missing Vulkan validation layer integration** — No debug messenger for catching Vulkan misuse during development.

---

## 7. Architecture Deep Dive

### View Resolution Pipeline

```
Developer's View struct
        |
        v
ViewResolver.resolve()
  - Mirror reflection to inject @Environment
  - Type-check against known primitives (Text, Button, etc.)
  - If primitive: create LayoutNode directly
  - If composite: recurse into view.body
  - If ModifiedView: resolve content, apply modifier
  - If TupleView: resolve each child with indexed path
  - If ConditionalView: resolve active branch
        |
        v
LayoutNode tree (with IDs, properties, event handlers)
        |
        v
LayoutEngine.resolve()
  - Root fills viewport
  - Recursive layoutChildren():
    - VStack: top-to-bottom, flex distribution
    - HStack: left-to-right, flex distribution
    - ZStack: centered overlay
    - FlexWrap: left-to-right with line breaks
    - ScrollView: offset content origin
        |
        v
RenderCollector.collect()
  - Walk tree, emit Quads (backgrounds)
  - Emit TextDrawCommands (text nodes)
  - Emit ImageDrawCommands (image nodes)
        |
        v
VulkanRenderer.drawFrame()
  - Record quad vertices -> quad pipeline
  - Record text vertices -> text pipeline (SDF)
  - Record image vertices -> image pipeline
  - Submit command buffer, present swapchain
```

### State Change Flow

```
User interaction (click, type, scroll)
        |
        v
Event handler mutates StateVar/State
        |
        v
StateTracker.markDirty(path:)
  - Sets dirty flag + records changed path
        |
        v
Main loop checks StateTracker.checkAndClear()
  - Returns dirty paths, resets flag
        |
        v
Snapshot previous positions (for animation)
        |
        v
Full view tree rebuild
  - contentBuilder() re-evaluated
  - ViewResolver resolves entire tree
  - LayoutEngine assigns positions/sizes
        |
        v
RenderCollector produces new draw commands
        |
        v
Renderer draws frame with new data
```

### Animation Flow

```
withAnimation(.spring(...)) {
    someState.value = newValue
}
        |
        v
AnimationEngine.currentAnimation set to .spring(...)
        |
        v
State setter calls markDirty()
        |
        v
View tree rebuilds with new values
        |
        v
LayoutNode.x/y/opacity didSet triggers animate()
  - Checks AnimationEngine.currentAnimation
  - If set: creates AnimationInstance (node + property + start/end + curve)
  - Adds to AnimationEngine.activeAnimations
        |
        v
AnimationEngine.currentAnimation cleared
        |
        v
Each frame: AnimationEngine.tick(deltaTime:)
  - Updates elapsed time on each AnimationInstance
  - Interpolates value using curve (spring/easing)
  - Applies to node property
  - Marks state dirty to trigger re-render
  - Removes completed animations
```

---

## 8. Module Map

| Module | Files | Responsibility |
|--------|-------|----------------|
| **Core** | `Raven.swift`, `RavenApp.swift`, `Types.swift` | App lifecycle, event loop, core types |
| **View System** | `View.swift`, `ViewBuilder.swift`, `ViewModifiers.swift`, `ViewResolver.swift` | Declarative DSL, parameter packs, modifier chains, view-to-node resolution |
| **State** | `State.swift` | `@State`, `@Binding`, `StateVar`, `@Published`, `StateTracker` |
| **Layout** | `LayoutEngine.swift`, `LayoutNode.swift` | Two-pass layout (measure + position), intrinsic size caching |
| **Animation** | `Animation.swift` | `AnimationEngine`, spring/easing physics, `withAnimation`, callback animations |
| **Environment** | `Environment.swift` | `@Environment`, `EnvironmentKey`, `EnvironmentValues`, `EnvironmentStore` |
| **Theme** | `Theme.swift` | 20 semantic color tokens, light/dark presets, `ThemeKey` |
| **Components** | `Components/` directory | `Text`, `Button`, `Spacer`, `Image`, `TextField`, `ScrollView`, `Stacks`, `FlowStack` |
| **Navigation** | `NavigationStack.swift`, `Sidebar.swift`, `Sheet.swift` | Stack nav, two-pane layout, modal overlay |
| **Renderer** | `Renderer/` directory | `VulkanRenderer`, `VulkanPipeline`, `VulkanBuffer`, `TextRenderer`, `ImageRenderer`, `FontManager`, `VulkanHelpers` |
| **Render Bridge** | `RenderCollector.swift` | Walks LayoutNode tree, produces draw command arrays |
| **Events** | `EventDispatcher.swift` | Hit testing, click dispatch, focus management |
| **Accessibility** | `Accessibility.swift`, `AccessibilityCollector.swift` | Semantic roles, tree collection |
| **Platform** | `Platform/RavenCore.swift` | Swift wrapper for Rust FFI (clipboard, file dialogs) |
| **Rust Core** | `rust/raven-core/` | Platform detection, clipboard (Win32/pbcopy/xclip), file dialogs (PowerShell/osascript/zenity) |
| **C Modules** | `CRavenCore/`, `CSDL3/`, `CVulkan/` | Module maps for Rust FFI, SDL3, Vulkan headers |
| **CLI** | `raven`, `raven.bat`, `cli/` | Build orchestration (Rust+Swift), dev mode, npm package |

---

## 9. Phased Development Roadmap

### Phase 1 — Foundation (COMPLETE)
- [x] Swift toolchain on Windows
- [x] SDL3 + Vulkan initialization
- [x] Basic text rendering (SDF via stb_truetype)
- [x] Basic layout (VStack/HStack/ZStack)
- [x] Primitive components (Text, Button, Spacer)
- [x] Swift/Rust FFI bridge (C FFI, static library)

### Phase 2 — Core Framework (COMPLETE)
- [x] Full layout engine (padding, alignment, flex, intrinsic caching)
- [x] Image component (texture loading via stb_image)
- [x] TextField (text input with focus management)
- [x] ScrollView (vertical/horizontal with scroll offset)
- [x] Animation system (spring physics, easing curves, withAnimation)
- [x] State management (@State, @Binding, StateVar, @Published, dirty tracking)
- [x] Environment system (@Environment, EnvironmentKey, scoped propagation)
- [x] Theme system (light/dark, 20 semantic tokens)
- [x] Navigation (NavigationStack, Sidebar, SidebarItem, Sheet)
- [x] Platform layer (clipboard, file dialogs via Rust)
- [x] FlowStack (flex-wrap) + baseline alignment
- [x] Raven CLI (build/run/dev/clean/version)
- [x] npm package published (swift-raven)

### Phase 3 — Hardening and Completeness (CURRENT)
**Goal: Fix all critical bugs, add missing essentials, ship on macOS**

#### Critical Fixes
- [ ] Fix font atlas UV recalculation on growth
- [ ] Fix LayoutNode.previousPositions memory leak (prune per frame)
- [ ] Fix spring physics NaN/overflow for edge case parameters
- [ ] Guard against zero-duration animations
- [ ] Fix text measurement to use actual fontSize
- [ ] Fix `raven init` dependency URL
- [ ] Add Vulkan error checking on all vkAllocate/vkCreate calls
- [ ] Fix resource leaks on Vulkan allocation failures
- [ ] Free SDL_strdup allocations

#### Essential Features
- [ ] ScrollView content clipping (per-element scissor rects)
- [ ] Multi-line text rendering (word wrap, newline support)
- [ ] Font size support (.font() modifier, variable fontSize in TextRenderer)
- [ ] ForEach component for dynamic collections
- [ ] List component (scrollable item collection)
- [ ] Divider component
- [ ] opacity, border, shadow, hidden, disabled modifiers
- [ ] onAppear / onDisappear lifecycle callbacks

#### Platform
- [ ] macOS builds via MoltenVK
- [ ] Linux build verification
- [ ] Cross-platform path handling in Package.swift (env vars, pkg-config)

### Phase 4 — Developer Experience (NEXT)
**Goal: Good enough that a developer chooses Raven over Tauri for a real project**

- [ ] Hot reload with state preservation
- [ ] Toggle, Slider, Picker, ProgressView components
- [ ] Alert, Menu, TabView components
- [ ] Keyboard navigation (Tab, Enter, Space)
- [ ] Screen reader integration
- [ ] System tray / menu bar integration
- [ ] OS dark mode detection
- [ ] Drag and drop
- [ ] Cross-compilation
- [ ] Performance profiler
- [ ] Pipeline cache for faster startup
- [ ] Vertex buffer growth strategy (reduce per-frame allocations)

### Phase 5 — Pro and Ecosystem (Year 2)
- [ ] Raven Studio — visual editor
- [ ] Advanced component library (data grids, rich text, charts)
- [ ] Enterprise licensing and support
- [ ] Conference talks and developer marketing

---

## 10. What Writing a Raven App Looks Like (Actual API)

```swift
import Raven

let selectedTab = StateVar("home")
let count = StateVar(0)
let showSheet = StateVar(false)

let app = RavenApp(title: "My App", width: 1024, height: 680) {
    Sidebar(width: 200) {
        VStack(alignment: .leading, spacing: 0) {
            Text("My App")
                .foreground(.white)
                .padding(16)

            SidebarItem(label: "Home", isSelected: selectedTab.value == "home") {
                selectedTab.value = "home"
            }
            SidebarItem(label: "Settings", isSelected: selectedTab.value == "settings") {
                selectedTab.value = "settings"
            }

            Spacer()
        }
    } detail: {
        VStack(spacing: 16) {
            Text("Count: \(count.value)")
                .foreground(.white)

            HStack(spacing: 12) {
                Button("Increment") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        count.value += 1
                    }
                }

                Button("Open Sheet") {
                    showSheet.value = true
                }
            }

            Spacer()
        }
        .padding(24)
    }

    Sheet(isPresented: showSheet.binding, width: 400, height: 250) {
        VStack(spacing: 16) {
            Text("Modal Content").foreground(.white)
            Button("Close") { showSheet.value = false }
        }
    }
}

app.run()
```

### CLI Tooling

```bash
# Install
npm install -g swift-raven

# Check prerequisites
raven doctor

# Build (Rust + Swift)
raven build

# Build and run
raven run

# Dev mode (watch for changes, auto-rebuild)
raven dev

# Create new project
raven init my-app

# Clean build artifacts
raven clean
```

---

## 11. Competitive Positioning

| Framework | Language | Native Feel | Same UI Everywhere | No WebView | Cross Compile | Desktop First |
|---|---|---|---|---|---|---|
| Electron | JS/HTML/CSS | No | Yes | No | Yes | No |
| Tauri | Rust + WebView | No | Yes | No | Yes | No |
| Flutter | Dart | Partial | Yes | Yes | Yes | No |
| Qt | C++ | Yes | Partial | Yes | Yes | Yes |
| SwiftUI | Swift | Yes | No | Yes | No | No |
| .NET MAUI | C# | Partial | No | Yes | Partial | No |
| **Raven** | **Swift** | **Yes** | **Yes** | **Yes** | **Planned** | **Yes** |

---

## 12. Target Audience

**Primary: Professional and Enterprise Developers**
- Teams building internal tooling for mixed Windows/Mac environments
- ISVs building professional desktop tools
- Developers from Apple's ecosystem who want Windows/Linux reach
- Teams maintaining separate native codebases looking to consolidate

**Secondary: Indie Developers and Solo Builders**
- Solo developers wanting native quality without three codebases
- Developers burned by Electron/Tauri looking for something genuinely better

---

## 13. Monetization

### Model: Open Source Core + Paid Pro

**Free / Open Source (MIT License)**
- Full framework — layout engine, renderer, component library, platform layer
- CLI tooling
- Standard component library
- Community support

**Raven Pro — Paid License**
- Advanced component library (data grids, rich text editors, charts)
- Raven Studio (visual layout editor)
- Priority support
- Performance profiler
- Early access to new features

---

## 14. Key Technical Resources

- **Swift on Windows** — swift.org/install/windows
- **Vulkan** — vulkan.lunarg.com
- **MoltenVK** — github.com/KhronosGroup/MoltenVK
- **SDL3** — libsdl.org
- **stb_truetype** — github.com/nothings/stb (font rendering)
- **stb_image** — github.com/nothings/stb (image loading)
- **SDF Text** — github.com/Chlumsky/msdfgen

---

## 15. What Raven Is Not

- Not a web technology — no HTML, CSS, JavaScript, or DOM
- Not a game engine — built for application UI, not real-time 3D
- Not mobile-first — desktop is the primary target
- Not a SwiftUI port — inspired by SwiftUI's API, not its implementation
- Not Apple-controlled — fully independent
- Not another Electron wrapper with a different name

---

## 16. The Vision

In five years Raven is the default answer when a professional developer asks "how do I build a cross-platform desktop app that doesn't feel like garbage."

Quality first. Everything else follows.

---

*This document represents the complete product vision, technical architecture, implementation status, known issues, and development roadmap for Raven as of March 2026.*
