# Raven Development Checklist

Tracks the implementation status of every major feature across all phases.

Source: [RAVEN_FRAMEWORK_DOCUMENT.md](RAVEN_FRAMEWORK_DOCUMENT.md)

---

## Phase 1 — Foundation

Goal: Get a window on screen with basic UI elements rendering via Vulkan.

- [x] Swift toolchain setup on Windows (verified 2026-03-26)
- [ ] Swift toolchain verified on macOS
- [ ] Swift toolchain verified on Linux
- [x] SDL3 integration — window creation and input (Windows, 2026-03-26)
- [ ] SDL3 verified on macOS
- [ ] SDL3 verified on Linux
- [x] Vulkan renderer — clear color, basic shapes, full pipeline (Windows, 2026-03-26)
- [ ] MoltenVK integration on macOS (code ready, needs hardware verification)
- [ ] Vulkan verified on Linux
- [x] Basic text rendering via SDF fonts (2026-03-26)
- [x] Basic layout engine — VStack, HStack, ZStack (2026-03-26)
- [x] Primitive components — Text, Button, Spacer (2026-03-26)
- [x] Swift/Rust FFI bridge — static library, C header, Swift wrapper (2026-03-26)
- [ ] Hello World running identically on all three platforms

---

## Phase 2 — Core Framework

Goal: Complete enough to build a real simple application.

- [x] Full layout engine — padding, spacing, alignment, constraints, intrinsic caching
- [x] Image component — PNG/JPG/BMP via stb_image + Vulkan textures
- [x] TextField — text input with cursor and focus management
- [x] ScrollView — vertical/horizontal scrolling with content clipping
- [x] ForEach — dynamic collection and range iteration
- [x] List — scrollable item list with auto dividers
- [x] Divider — visual separator
- [x] FlowStack — flex-wrap horizontal layout
- [x] Baseline alignment in HStack
- [x] State management — @State, @Binding, StateVar, @Published, dirty tracking
- [x] Environment system — @Environment, EnvironmentKey, scoped propagation
- [x] Theme system — light/dark presets, 20 semantic color tokens
- [x] Animation system — spring physics, easing curves, withAnimation, callback animations
- [x] Layout transition animations — path-based identity for continuity
- [x] NavigationStack — push/pop route-based navigation
- [x] Sidebar — two-pane layout with fixed sidebar + flexible detail
- [x] Sheet — modal overlay with backdrop dismiss
- [x] Platform layer — clipboard (get/set), file dialogs (open/save/folder) via Rust
- [x] Raven CLI — build, run, dev, clean, init, doctor, version
- [x] npm package published (swift-raven)
- [x] ViewBuilder with parameter packs — unlimited children
- [ ] Basic hot reload (raven dev does full restart, not incremental)
- [ ] First public documentation site

---

## Phase 3 — Hardening and Completeness

Goal: Fix all critical bugs, add missing essentials, ship on macOS.

### Critical Fixes (All Done)

- [x] Fix font atlas UV recalculation on growth (direct `*= 0.5`)
- [x] Fix LayoutNode.previousPositions memory (cleared each frame)
- [x] Fix spring physics NaN/overflow (parameter clamping + NaN guards)
- [x] Guard against zero-duration animations
- [x] Fix text measurement to use actual fontSize
- [x] Fix `raven init` dependency URL
- [x] Fix Vulkan resource leaks on allocation failures (defer cleanup guards)
- [x] Free SDL_strdup allocations
- [x] Fix force unwraps in renderer (guard-let patterns)
- [x] Fix AnimationInstance retain cycle (weak node reference)
- [x] Add vertex buffer geometric growth (2x) to avoid per-frame realloc

### Essential Features (All Done)

- [x] ScrollView content clipping (per-element scissor rects via ClipRect)
- [x] Multi-line text rendering (word wrap + `\n` support)
- [x] Font size control (.font modifier, variable fontSize)
- [x] ForEach component for dynamic collections
- [x] List component (scrollable list with dividers)
- [x] Divider component
- [x] opacity, border, shadow, hidden, disabled modifiers
- [x] onAppear / onDisappear lifecycle callbacks (ID-based diffing)
- [x] onTapGesture modifier
- [x] textWrap modifier for explicit word wrap width
- [x] Rust file dialog filter support (Windows/macOS/Linux)
- [x] Rust error context (raven_core_last_error)

### Platform (Remaining)

- [ ] macOS builds via MoltenVK (code ready, awaiting hardware)
- [ ] Linux build verification
- [ ] Cross-platform path handling in Package.swift (env vars, pkg-config)

### Tooling

- [x] `raven bundle` command for distribution packaging
- [x] Windows bundle — .exe + DLLs + resources
- [x] macOS bundle — .app structure with Info.plist
- [x] Linux bundle — bin/ + lib/ + launcher script

---

## Phase 4 — Developer Experience

Goal: Good enough that a developer chooses Raven over Tauri for a real project.

- [ ] Hot reload with state preservation
- [ ] Toggle component
- [ ] Slider component
- [ ] Picker / Dropdown component
- [ ] ProgressView component
- [ ] Alert / dialog component
- [ ] Menu component
- [ ] TabView component
- [ ] Keyboard navigation (Tab, Enter, Space between focusable elements)
- [ ] Screen reader integration (platform accessibility APIs)
- [ ] System tray / menu bar integration
- [ ] OS dark mode detection
- [ ] Drag and drop support
- [ ] Cross-compilation (build any platform from any platform)
- [ ] Performance profiler
- [ ] VkPipelineCache for faster startup
- [ ] Vulkan validation layer debug messenger
- [ ] SVG / vector graphics support

---

## Phase 5 — Pro and Ecosystem (Year 2)

- [ ] Raven Studio — visual layout editor
- [ ] Advanced component library (data grids, rich text, charts)
- [ ] Enterprise licensing and support program
- [ ] Conference talks and developer marketing
- [ ] Official showcase of apps built with Raven
- [ ] Community forum and Discord
- [ ] Package ecosystem — third-party component packages via SPM

---

## Known Issues (Current)

1. **Thread safety** — All singletons are main-thread-only. Documented, safe for now, needs isolation if async work is introduced.
2. **Hardcoded component styling** — Button, TextField, Sheet, SidebarItem have baked-in dimensions. Should be theme-configurable.
3. **Version scattered across 5 files** — No single source of truth for "0.1.0".
4. **Windows-only SDK paths** — Package.swift hardcodes vendor paths and VulkanSDK version.
5. **No pipeline cache** — Vulkan pipelines recreated from scratch every launch.
6. **No validation layer integration** — No debug messenger for Vulkan development.
