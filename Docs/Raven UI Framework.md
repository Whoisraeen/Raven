# Raven UI Framework — Codebase Analysis & Work Breakdown

Based on an audit of the current codebase and documentation (`RAVEN_FRAMEWORK_DOCUMENT.md` and `Development Checklist.md`), the core rendering engine and layout fundamentals for Windows are successfully completed. The foundation (Phase 1 & 2) is solid.

However, to complete the framework and reach production-level quality across platforms (Phase 3 & 4), the following items require attention. They are broken down by category and priority.

---

> [!WARNING] 
> **Critical Blockers**
> Before releasing to developers, the framework must address hardcoded UI styles and unsafe singletons, and it must compile and run on macOS and Linux as promised via MoltenVK and platform-agnostic build paths.

## 1. High Priority Bugs & Technical Debt

### A. Thread Safety 
Currently, the major singletons maintain their state on the main thread and assume a single-threaded execution model. Introducing Swift concurrency (`async`/`await`) will cause race conditions.
- **Action**: Implement actor-isolation or `NSRecursiveLock`/OS-level mutexes for `StateTracker.shared`, `AnimationEngine.shared`, `EnvironmentStore.shared`, `FontManager.shared`, and `FocusManager.shared`.

### B. Hardcoded Component Styling
The `ViewResolver.swift` handles primitive resolution but injects hardcoded styling properties rather than deriving them from the `Theme` or modifier chains.
- **Action**: Move hardcoded constants to `EnvironmentStore.shared.current.theme`.
- *Specifics found in code*:
  - `Button` has `cornerRadius = 6`
  - `TextField` has `fixedWidth = 200`
  - `TextField` has `cornerRadius = 4`
  - `Sheet` has `cornerRadius = 12`
  - `Sidebar` uses a fixed `8` padding layout
  - `Divider` gets a hardcoded `fixedHeight = 1`

### C. Build Configuration & Versioning
- **Action 1 (Paths)**: Remove Windows-only paths from `Package.swift` (e.g., `C:/VulkanSDK/1.4...` & `vendor/SDL3/...`). Replace with `pkg-config` or systematic environment variable detection that supports both x64 and ARM64.
- **Action 2 (Single Source of Truth)**: Consolidate the "0.1.0" version string. Currently, it is duplicated across `Cargo.toml`, `cli/package.json`, `raven`, `raven.js`, and the Rust library. 

---

## 2. Platform Portability (Phase 3 Finish Line)

The cross-platform claim is currently pending verification outside of Windows.
- **macOS Build**: Verify MoltenVK integration via `VK_KHR_portability_enumeration` and `VK_KHR_portability_subset`. Needs live hardware execution and validation of `Package.swift` rules.
- **Linux Build**: Verify `swift build` on a Linux environment (Ubuntu) assuring `libsdl3-dev` and Vulkan SDK bindings resolve correctly via `pkg-config`.
- **Rust FFI Cross-Platform Behavior**: Ensure `osascript` (macOS) and `zenity` (Linux) function as expected for clipboard and file dialog functionality.

---

## 3. Renderer Optimizations (Medium Priority)

> [!TIP]
> **Performance Improvements**
> Implementing Vulkan Pipeline Caching will drastically reduce application startup times by caching compiled shaders.

- **Vulkan Pipeline Cache**: Instantiate and load `VkPipelineCache`. Save the cache to disk on shutdown, and load it on boot to prevent recreating rendering pipelines from scratch every launch.
- **Validation Layers**: Implement `VK_EXT_debug_utils`. Bind a debug messenger callback so that downstream developers (and yourself) can catch incorrect Vulkan API usage immediately. 

---

## 4. Missing Components & Developer Experience (Phase 4)

To replace solutions like Tauri or Electron, Raven requires a complete set of desktop-specific interactions.

### A. Missing Core UI Components
- **Form Controls:** Toggle, Slider, Picker 
- **Feedback:** ProgressView, Alert (System Dialog vs Custom), Menu (Context + MenuBar)
- **Navigation:** TabView/Window Tabs

### B. Interactive Behavior & DX
- **Keyboard Navigation**: Implement a traversal system for `Tab` index, `Enter` (Action), and `Space` (Toggle). Currently, only `TextField` captures focus.
- **A11y**: Extend the existing accessibility tree collection to hook into native Screen Reader APIs (UIAutomation for Windows).
- **Drag and Drop**: Receptivity for dragging files into the window (requires bridging SDL3 drop events to the `EventDispatcher`).
- **Dark Mode Detection**: Tie the `Theme` engine to the OS-level light/dark mode preference via the Rust FFI.

### C. Developer Tooling
- **Hot Reload**: The `raven dev` command restarts the app. Implementing hot-module-reloading (or state-preserved dynamic library reloading) is crucial.
- **Performance Profiler**: A simple overlay to highlight dirty rectangle renders, render ms/frame, and layout ms/frame.

You will have to manually build an accessibility tree and bridge it to Windows UIAutomation, macOS Accessibility API, and Linux ATSPI.

The Rich Text Problem: Displaying a paragraph is easy. Building a <RichTextEditor> component that supports copying, pasting, bolding, undo/redo history, and cursor placement is incredibly hard. If a developer wants to build a Notion or Slack clone with Raven, the lack of a robust text editor component will be a hard blocker.
Embedding Native Views: What happens if a developer wants to embed a Google Map or an embedded Web Browser inside your app? With Tauri or React Native, you just drop in a Webview. Because you draw your own pixels via Vulkan, "punching a hole" in your Vulkan swapchain to embed an OS-native webview widget perfectly in sync with your scrolling layout is very difficult.
The "Trough of Sorrow": Right now, building the core layout engine is fun. In a year, when you are debugging an obscure issue where the mouse cursor flickers only on Ubuntu 24.04 Wayland with fractional scaling turned on... that is the grind that kills most independent UI frameworks.

### Remaining Issues

#### High Priority

1. **Thread safety across all singletons** — `StateTracker.shared`, `AnimationEngine.shared`, `EnvironmentStore.shared`, `FontManager.shared`, `FocusManager.shared` all have mutable state without synchronization. Currently safe because single-threaded, but documented as main-thread-only. Will need proper isolation if async work is introduced.

2. **Hardcoded component styling** — Button cornerRadius=6, TextField fixedWidth=200, Sheet cornerRadius=12, SidebarItem padding, all baked into ViewResolver rather than configurable via modifiers or theme.

3. **Version scattered across 5 files** — `Cargo.toml`, `cli/package.json`, `raven` script, `raven.js`, and Rust lib all declare "0.1.0" independently. No single source of truth.

4. **Windows-only SDL3/Vulkan paths** — Package.swift hardcodes `vendor/SDL3/SDL3-3.4.2/lib/x64` (no ARM64) and `C:/VulkanSDK/1.4.341.1/` (version-specific). Linux assumes `/usr/lib`.

#### Medium Priority

5. **No pipeline cache** — Vulkan pipelines recreated from scratch on every app launch. No `VkPipelineCache` for startup optimization.

6. **Missing Vulkan validation layer integration** — No debug messenger for catching Vulkan misuse during development.