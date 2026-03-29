# Improvement Tasks for Raven Framework

The following tasks capture identified problem areas in the Raven framework, each with a detailed description of the issue and a concrete solution proposal. Use this `task.md` as a living checklist during development.

- `[ ]` **Atlas Packing Optimization**
  - **Problem:** The current texture atlas grows exponentially and uses a naïve packing algorithm (`packGlyph`). This can lead to wasted space and frequent atlas reallocations, especially when many glyphs of varying sizes are requested.
  - **Solution:** Replace the simple row‑based packing with a Skyline or MaxRects bin‑packing algorithm. Implement incremental growth (e.g., add rows/columns only as needed) and expose a method to compact the atlas when it becomes fragmented. Update `FontManager.growAtlas()` to preserve existing UVs correctly.

- `[ ]` **String Measurement Caching**
  - **Problem:** `FontManager.measureText` iterates over every character on each layout pass, even for static strings that never change, causing unnecessary CPU work.
  - **Solution:** Introduce a thread‑safe cache (`Dictionary<String, (width: Float, height: Float)>`). Store measurements keyed by the string and font size. Invalidate the cache only when the font is reloaded or the font size changes. Update layout code to query the cache before measuring.

- `[ ]` **Parallel Layout Engine**
  - **Problem:** Layout passes are performed on a single thread. For deep UI trees (e.g., complex dashboards) this becomes a performance bottleneck.
  - **Solution:** Refactor `LayoutEngine` to split the measure phase into independent sub‑trees that can be processed concurrently using Swift’s `Task` concurrency model. Ensure that intrinsic size calculations are pure (no side effects) and then combine results in the position pass.

- `[ ]` **Platform‑Specific Accessibility Integration**
  - **Problem:** The accessibility tree is generated (`AccessibilityCollector`) but never exposed to the underlying OS, limiting assistive‑technology support.
  - **Solution:** Add a C‑FFI function in `rust/raven-core` that returns the serialized accessibility tree (e.g., JSON). Implement platform adapters:
    - Windows: Use UI Automation APIs to create corresponding `IAccessible` objects.
    - macOS: Use the Accessibility (AX) framework to publish the tree.
    - Linux: Provide AT‑SPI2 integration.
  - Update `RavenApp` to call the export after each layout pass and optionally log the tree for debugging.

- `[ ]` **Hot‑Reload / Incremental Compilation**
  - **Problem:** Developers must restart the entire application to see UI changes, slowing iteration.
  - **Solution:** Introduce a file‑watcher (e.g., using `DispatchSourceFileSystemObject`) that monitors source files for changes. When a change is detected, re‑run `ViewResolver` and `LayoutEngine` without recreating the Vulkan device or window. Preserve the existing atlas and only upload new glyphs if needed.

- `[ ]` **Animation Instance Pruning**
  - **Problem:** Finished `AnimationInstance`s remain in `AnimationEngine.shared` until the next frame, potentially leaking memory in long‑running sessions.
  - **Solution:** After each update tick, filter out completed animations (`instance.isFinished`). Provide a configurable maximum animation pool size and reuse instances to reduce allocation churn.

- `[ ]` **Incremental Atlas Updates**
  - **Problem:** When a new glyph is added, the entire atlas texture is marked dirty and re‑uploaded, even though only a small region changed.
  - **Solution:** Track dirty rectangles per glyph insertion. Modify the Vulkan upload routine to perform a sub‑region update (`vkCmdCopyBufferToImage` with offset/extent) instead of a full texture upload.

- `[ ]` **Robust Error Handling & Logging**
  - **Problem:** Many functions (`loadFont`, `getGlyph`) print to console but return generic `Bool`/`nil`, making debugging difficult.
  - **Solution:** Replace simple prints with a structured logging system (e.g., `os_log` on macOS, `spdlog` on Windows). Propagate detailed error enums (`FontError`, `AtlasError`) up the call stack, allowing the UI to display user‑friendly messages.

- `[ ]` **Comprehensive Unit & Integration Tests**
  - **Problem:** The codebase lacks automated tests for layout correctness, text measurement, and accessibility mapping.
  - **Solution:** Add XCTest targets covering:
    - Intrinsic size calculations for various view hierarchies.
    - Correct UV generation after atlas growth.
    - Accessibility tree generation for common components.
    - Animation interpolation edge cases.

- `[ ]` **Documentation & Developer Guide Updates**
  - **Problem:** The existing docs focus on high‑level architecture but omit detailed guides for extending the framework (e.g., adding a custom view, integrating a new platform).
  **Solution:** Expand `Docs/` with:
    - "Creating Custom Views" tutorial.
    - "Extending the Renderer" guide (adding new shader pipelines).
    - Platform‑specific sections for Windows, macOS, Linux.
    - API reference generation using `swift-doc` and publishing to a static site.

- `[ ]` **Performance Profiling Infrastructure**
  - **Problem:** No built‑in profiling hooks to measure frame time, layout duration, or GPU submission latency.
  - **Solution:** Integrate a lightweight profiler (e.g., `signpost` on Apple platforms, `Event Tracing for Windows` on Windows). Emit timestamps for key stages (event handling, layout, animation, render collection, GPU submit) and visualize results in a simple UI overlay.

---

- `[ ]` **Cross‑Platform Build Verification**
  - **Problem:** No CI or verification that the project builds for all target architectures (Windows x64/ARM64, macOS Intel/Apple Silicon, macOS 12+, Linux distributions).
  - **Solution:** Set up GitHub Actions matrix builds using `swift build` and `cargo build` for each target. Add scripts to compile the Rust core for each triple, verify linking, and run a minimal smoke test. Fail the CI if any target fails.

- `[ ]` **Windows System Tray Integration (Rust)**
  - **Problem:** The framework lacks a way to place an icon in the Windows system tray and handle clicks.
  - **Solution:** Use the `windows` crate to call `Shell_NotifyIconW`. Expose a Swift‑side API (`RavenApp.addSystemTray(icon: String, onClick: () -> Void)`). Implement the Rust side to manage the tray and forward events via FFI.

- `[ ]` **Native Windowing & Custom Title Bar per Platform**
  - **Problem:** Current window is a plain SDL window with no custom chrome, limiting UI integration.
  - **Solution:** Abstract a `WindowManager` interface in Rust with platform‑specific implementations (Win32, Cocoa, X11/Wayland). Provide APIs to hide the default title bar, draw a custom bar using Raven UI, and expose window controls (minimize, maximize, close). Use `SDL_SetWindowBordered` where possible and fall back to native APIs.

- `[ ]` **Full Platform API Access via Rust**
  - **Problem:** No unified Rust bindings for OS services (clipboard, file dialogs, notifications).
  - **Solution:** Create a `platform` crate exposing safe Rust wrappers for Windows (`winapi`/`windows`), macOS (`cocoa`), Linux (`gtk`/`x11`). Export through FFI to Swift. Document usage in `Docs/PlatformAPI.md`.

- `[ ]` **Complex App Feasibility Audit**
  - **Problem:** Unclear if Raven can support modern, feature‑rich apps like Arc Browser, Discord, DaVinci Resolve.
  - **Solution:** Conduct a gap analysis: list required features (web engine, rich text chat, video playback, GPU‑accelerated effects). Identify missing subsystems (WebView, audio/video pipelines, multi‑window management). Propose incremental roadmap: integrate a WebView (e.g., `WebKitGTK`/`WebView2`), add audio via `SDL_mixer` or `PortAudio`, support multiple windows, implement GPU‑based video decoding. Document findings in `Docs/FeasibilityAudit.md`.

---

*Use this `task.md` as the source of truth for the upcoming sprint. Mark items as `[/]` when work begins and `[x]` when completed.*
