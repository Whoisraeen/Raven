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
- [x] State management system - @State, @Binding, @Observable equivalents
  Complete on 2026-03-26. @State, @Published, @Binding, StateVar, ObservableObject, StateTracker. Frame caching (only re-render on state change).
- [ ] Animation system - transitions, springs, easing
- [ ] Theme system - colors, typography, spacing scales
- [ ] Navigation patterns - window management, modal sheets, sidebar
- [ ] Platform layer - file system, clipboard, notifications, drag and drop
- [ ] Raven CLI - new, build, run commands
- [ ] Basic hot reload
- [ ] First public documentation site

## Phase 3 - Developer Experience (Months 8-12)

Goal: Good enough that a developer chooses Raven over Tauri for a real project

- [ ] Cross-compilation - build any platform target from any platform
- [ ] Full hot reload with state preservation
- [ ] Performance profiler
- [ ] Accessibility layer - screen reader support on all platforms
- [ ] System integration - tray icons, menu bar, OS notifications, dark mode
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
