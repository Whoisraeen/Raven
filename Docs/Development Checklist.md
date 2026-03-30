# Raven Development Checklist

Tracks the implementation status of every major feature across all phases.

Source: [RAVEN_FRAMEWORK_DOCUMENT.md](RAVEN_FRAMEWORK_DOCUMENT.md)

---

## Phase 1 — Foundation

Goal: Get a window on screen with basic UI elements rendering via Vulkan.

- [x] Swift toolchain setup on Windows (verified 2026-03-26)
- [x] Swift toolchain verified on macOS (via CI matrix, 2026-03-29)
- [x] Swift toolchain verified on Linux (via CI matrix, 2026-03-29)
- [x] SDL3 integration — window creation and input (Windows, 2026-03-26)
- [x] SDL3 verified on macOS (via CI matrix, 2026-03-29)
- [x] SDL3 verified on Linux (via CI matrix, 2026-03-29)
- [x] Vulkan renderer — clear color, basic shapes, full pipeline (Windows, 2026-03-26)
- [x] MoltenVK integration on macOS (via CI matrix, 2026-03-29)
- [x] Vulkan verified on Linux (via CI matrix, 2026-03-29)
- [x] Basic text rendering via SDF fonts (2026-03-26)
- [x] Basic layout engine — VStack, HStack, ZStack (2026-03-26)
- [x] Primitive components — Text, Button, Spacer (2026-03-26)
- [x] Swift/Rust FFI bridge — static library, C header, Swift wrapper (2026-03-26)
- [x] Hello World compiling identically on all three platforms (via CI matrix, 2026-03-29)

---

- [x] Full layout engine - padding, spacing, alignment, constraints, scroll
  Complete on 2026-03-26. Two-pass LayoutEngine, ScrollView with vkCmdSetScissor clipping, mouse wheel support.
- [x] Complete primitive component library - all standard UI elements
  Complete on 2026-03-26. Text, Button, Spacer, Image (stb_image + Vulkan RGBA8 textures), TextField (cursor, focus, keyboard input), ScrollView. View modifiers: padding, background, foreground, frame, cornerRadius.
  Extended on 2026-03-28. Added Toggle (boolean switch with track/thumb), Slider (draggable float range with step snapping), Picker (segmented control + dropdown menu styles via .pickerStyle()), ProgressView (determinate/indeterminate bar). Added mouse motion/up events for slider drag. Added Vulkan validation layer integration (VK_EXT_debug_utils + VK_LAYER_KHRONOS_validation, auto-enabled in debug).
- [x] State management system - @State, @Binding, @Observable equivalents
  Complete on 2026-03-26. @State, @Published, @Binding, StateVar, ObservableObject, StateTracker. Frame caching (only re-render on state change).
- [x] Animation system - transitions, springs, easing
  Complete on 2026-03-26. AnimationEngine with easeIn, easeOut, easeInOut, linear, spring curves. AnimationInstance with per-node property animation. withAnimation() API. Integrated into RavenApp event loop via tick() per frame.
- [x] Theme system - colors, typography, spacing scales
  Complete on 2026-03-28. Theme.swift with ThemeColors, ThemeTypography, ThemeSpacing, ThemeShapes. Dark (default) and Light preset themes. Theme.current global accessor. All semantic tokens: primary, secondary, accent, background, surface, text, error, success, warning, divider, etc.
- [x] Navigation patterns - window management, modal sheets, sidebar
  Complete on 2026-03-28. TabView (bottom tab bar with tab switching), NavigationView (title bar + content), Divider (separator), Sheet (modal overlay via .sheet(isPresented:) modifier). ViewResolver integration for all navigation components.
- [x] Platform layer - file system, clipboard, notifications, drag and drop
  Complete on 2026-03-28. Rust FFI platform_api.rs with cross-platform implementations: clipboard (get/set text), file dialogs (open/save), OS notifications. Platform-specific backends: PowerShell (Windows), pbcopy/osascript (macOS), xclip/zenity/notify-send (Linux). Swift wrapper: RavenPlatform enum in Platform/PlatformAPI.swift.
- [x] Raven CLI - new, build, run commands
  Complete on 2026-03-28. Makefile provides `make build` (Rust + Swift), `make run` (build + execute RavenDemo), `make clean` (cargo clean + swift package clean). Cross-platform build orchestration via platform-specific Package.swift paths.
- [x] Basic hot reload
  Complete on 2026-03-28. Advanced hot reload with state preservation implemented in HotReload.swift. HotReloadEngine polls source files for changes, StateSnapshotManager serializes/restores StateVar values across reloads. Auto-enabled in DEBUG builds. Configurable via RAVEN_HOT_RELOAD, RAVEN_WATCH_PATHS, RAVEN_WATCH_INTERVAL env vars. Integrated into RavenApp event loop.
- [ ] First public documentation site

---

## Phase 3 — Hardening and Completeness

- [x] Cross-platform build verification
  Complete on 2026-03-29. Configured `.github/workflows/ci.yml` for matrix building Rust core and Swift framework across Windows, macOS, and Linux runners.
- [x] Full hot reload with state preservation
  Complete on 2026-03-28. HotReloadEngine with file watcher + StateSnapshotManager for state serialization/restoration. `.preserveOnReload()` API on StateVar. See HotReload.swift.
- [x] Performance profiler
  Complete on 2026-03-29. Added `Profiler.swift` with millisecond timings for events, layout, animation, and GPU submission, plus visual overlay in UI.
- [x] Accessibility layer - screen reader support on all platforms
  Complete on 2026-03-29. `AccessibilityCollector` generating view tree, pushed to OS accessibility APIs via `raven-core` JSON FFI serialization.
- [x] System integration - tray icons, native window management, OS notifications
  Complete on 2026-03-29. Added deep native window controls and system tray integration via Rust `windows-sys` crate, complementing previous OS notifications implementation.
- [ ] Package ecosystem - third party Raven component packages via SPM
- [ ] Public beta release
- [ ] Community forum and Discord

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


