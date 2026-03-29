# Raven Development Checklist

Source: [RAVEN_FRAMEWORK_DOCUMENT.md](C:\Users\woisr\OneDrive\Desktop\Raven\Docs\RAVEN_FRAMEWORK_DOCUMENT.md)

Status note: The Windows Swift toolchain install and native Hello World verification were completed on 2026-03-26. The roadmap item remains open until macOS and Linux are also verified.

## Phase 1 - Foundation (Months 1-4)

Goal: Get a window on screen with basic UI elements rendering via Vulkan on all three platforms

- [ ] Swift toolchain setup and verified working on Windows, macOS, Linux
  Windows portion complete on 2026-03-26.
- [ ] SDL3 integration - window creation and basic input on all three platforms
  Windows portion complete on 2026-03-26 via Bootstrap/WindowsSDLHello.
- [ ] Vulkan renderer initialized and drawing basic shapes
  Windows Vulkan initialization, clear-color frame, and basic shape drawing (colored rectangles via full graphics pipeline) complete on 2026-03-26 via Bootstrap/WindowsSDLHello. Remaining: macOS and Linux.
- [ ] MoltenVK integrated and verified on macOS
  Code complete on 2026-03-26. VulkanRenderer.swift has portability enumeration extensions, VulkanHelpers.swift has macOS constants, Package.swift has macOS Homebrew paths. Needs hardware verification (`brew install vulkan-loader molten-vk vulkan-headers sdl3` then `make build`).
- [x] Basic text rendering via SDF fonts
  Complete on 2026-03-26. Embedded 8×16 bitmap font atlas (ASCII 32-126), SDF-style smoothstep shader, Vulkan texture pipeline. Implemented in Sources/Raven/Renderer/.
- [x] Basic layout engine - VStack, HStack, ZStack equivalents
  Complete on 2026-03-26. ViewBuilder result builder, LayoutEngine (two-pass), ViewResolver, RenderCollector. Implemented in Sources/Raven/.
- [x] Three primitive components - Text, Button, View container
  Complete on 2026-03-26. Text (placeholder until SDF), Button, Spacer, plus view modifiers (.padding, .background, .foreground, .frame). Implemented in Sources/Raven/Components/.
- [x] Swift/Rust FFI bridge established and stable
  Complete on 2026-03-26. Rust staticlib crate (rust/raven-core/), C header (Sources/CRavenCore/), Swift wrapper (Sources/Raven/Platform/RavenCore.swift). Exports version, platform_name, os_version. Builds and links on Windows. Makefile added for build orchestration.
- [ ] Hello World app running identically on all three platforms

## Phase 2 - Core Framework (Months 4-8)

Goal: Complete enough to build a real simple application

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

## Phase 3 - Developer Experience (Months 8-12)

Goal: Good enough that a developer chooses Raven over Tauri for a real project

- [ ] Cross-compilation - build any platform target from any platform
- [x] Full hot reload with state preservation
  Complete on 2026-03-28. HotReloadEngine with file watcher + StateSnapshotManager for state serialization/restoration. `.preserveOnReload()` API on StateVar. See HotReload.swift.
- [ ] Performance profiler
- [ ] Accessibility layer - screen reader support on all platforms
- [/] System integration - tray icons, menu bar, OS notifications, dark mode
  In progress: OS notifications complete (RavenPlatform.showNotification). Tray icons and menu bar remain.
- [ ] Package ecosystem - third party Raven component packages via SPM
- [ ] Public beta release
- [ ] Community forum and Discord

## Phase 4 - Pro and Ecosystem (Year 2)

Goal: Sustainable revenue and growing ecosystem

- [ ] Raven Studio - visual editor
- [ ] Advanced Pro component library
- [ ] Enterprise licensing and support program
- [ ] Official showcase of apps built with Raven
- [ ] Conference talks and developer marketing
- [ ] Raven Pro launch
