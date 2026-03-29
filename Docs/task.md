
# Improvement Tasks for Raven Framework

The following tasks capture identified problem areas in the Raven framework, each with a detailed description of the issue and a concrete solution proposal. Use this `task.md` as a living checklist during development.

- `[ ]` **Atlas Packing Optimization**
  - **Problem:** The current texture atlas grows exponentially and uses a naïve packing algorithm (`packGlyph`). This can lead to wasted space and frequent atlas reallocations, especially when many glyphs of varying sizes are requested.
  - **Solution:** Replace the simple row‑based packing with a Skyline or MaxRects bin‑packing algorithm. Implement incremental growth (e.g., add rows/columns only as needed) and expose a method to compact the atlas when it becomes fragmented. Update `FontManager.growAtlas()` to preserve existing UVs correctly.

- `[x]` **String Measurement Caching**
  - **Problem:** `FontManager.measureText` iterates over every character on each layout pass, even for static strings that never change, causing unnecessary CPU work.
  - **Solution:** Introduce a thread‑safe cache (`Dictionary<String, (width: Float, height: Float)>`). Store measurements keyed by the string and font size. Invalidate the cache only when the font is reloaded or the font size changes. Update layout code to query the cache before measuring.
  - **Completed:** 2026-03-28. Added `MeasurementKey` + `measurementCache` in `FontManager.swift` with `NSLock` thread safety. Cache checks on every call; `invalidateMeasurementCache()` exposed for font reload.

- `[ ]` **Parallel Layout Engine**
  - **Problem:** Layout passes are performed on a single thread. For deep UI trees (e.g., complex dashboards) this becomes a performance bottleneck.
  - **Solution:** Refactor `LayoutEngine` to split the measure phase into independent sub‑trees that can be processed concurrently using Swift's `Task` concurrency model. Ensure that intrinsic size calculations are pure (no side effects) and then combine results in the position pass.

- `[ ]` **Platform‑Specific Accessibility Integration**
  - **Problem:** The accessibility tree is generated (`AccessibilityCollector`) but never exposed to the underlying OS, limiting assistive‑technology support.
  - **Solution:** Add a C‑FFI function in `rust/raven-core` that returns the serialized accessibility tree (e.g., JSON). Implement platform adapters:
    - Windows: Use UI Automation APIs to create corresponding `IAccessible` objects.
    - macOS: Use the Accessibility (AX) framework to publish the tree.
    - Linux: Provide AT‑SPI2 integration.
  - Update `RavenApp` to call the export after each layout pass and optionally log the tree for debugging.

- `[x]` **Hot‑Reload / Incremental Compilation**
  - **Problem:** Developers must restart the entire application to see UI changes, slowing iteration.
  - **Solution:** Introduce a file‑watcher (e.g., using `DispatchSourceFileSystemObject`) that monitors source files for changes. When a change is detected, re‑run `ViewResolver` and `LayoutEngine` without recreating the Vulkan device or window. Preserve the existing atlas and only upload new glyphs if needed.
  - **Completed:** 2026-03-28. Implemented advanced hot reload with state preservation in `HotReload.swift`. `HotReloadEngine` polls `.swift` files for modification time changes. `StateSnapshotManager` serializes all registered `StateVar` values before reload and restores them after. `.preserveOnReload("key")` API on StateVar. Auto-enabled in DEBUG builds. Configurable via `RAVEN_HOT_RELOAD`, `RAVEN_WATCH_PATHS`, `RAVEN_WATCH_INTERVAL` environment variables. Integrated into `RavenApp.run()` event loop with lifecycle management.

- `[x]` **Animation Instance Pruning**
  - **Problem:** Finished `AnimationInstance`s remain in `AnimationEngine.shared` until the next frame, potentially leaking memory in long‑running sessions.
  - **Solution:** After each update tick, filter out completed animations (`instance.isFinished`). Provide a configurable maximum animation pool size and reuse instances to reduce allocation churn.
  - **Completed:** Already implemented in `Animation.swift` — the `tick()` method filters `isFinished` instances each frame. The `activeAnimations` array is rebuilt with only non‑finished entries.

- `[ ]` **Incremental Atlas Updates**
  - **Problem:** When a new glyph is added, the entire atlas texture is marked dirty and re‑uploaded, even though only a small region changed.
  - **Solution:** Track dirty rectangles per glyph insertion. Modify the Vulkan upload routine to perform a sub‑region update (`vkCmdCopyBufferToImage` with offset/extent) instead of a full texture upload.

- `[x]` **Robust Error Handling & Logging**
  - **Problem:** Many functions (`loadFont`, `getGlyph`) print to console but return generic `Bool`/`nil`, making debugging difficult.
  - **Solution:** Replace simple prints with a structured logging system (e.g., `os_log` on macOS, `spdlog` on Windows). Propagate detailed error enums (`FontError`, `AtlasError`) up the call stack, allowing the UI to display user‑friendly messages.
  - **Completed:** 2026-03-28. Created `Logger.swift` with `RavenLogger` enum (debug/info/warning/error/critical levels), auto‑filtering by build mode, `#fileID`/`#line` source locations. Added error types: `FontError`, `RendererError`, `PlatformError`.

- `[ ]` **Comprehensive Unit & Integration Tests**
  - **Problem:** The codebase lacks automated tests for layout correctness, text measurement, and accessibility mapping.
  - **Solution:** Add XCTest targets covering:
    - Intrinsic size calculations for various view hierarchies.
    - Correct UV generation after atlas growth.
    - Accessibility tree generation for common components.
    - Animation interpolation edge cases.

- `[x]` **Documentation & Developer Guide Updates**
  - **Problem:** The existing docs focus on high‑level architecture but omit detailed guides for extending the framework (e.g., adding a custom view, integrating a new platform).
  - **Solution:** Expand `Docs/` with:
    - "Creating Custom Views" tutorial.
    - "Extending the Renderer" guide (adding new shader pipelines).
    - Platform‑specific sections for Windows, macOS, Linux.
    - API reference generation using `swift-doc` and publishing to a static site.
  - **Completed:** 2026-03-28. Created `COMPONENT_API_REFERENCE.md` (full component + modifier reference), updated `GETTING_STARTED.md` (with all new components, theme, platform APIs), updated `ARCHITECTURE.md` references. `API_REFERENCE.md` was already comprehensive. Remaining: custom view tutorial, static site generation.

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

- `[x]` **Full Platform API Access via Rust**
  - **Problem:** No unified Rust bindings for OS services (clipboard, file dialogs, notifications).
  - **Solution:** Create a `platform` crate exposing safe Rust wrappers for Windows (`winapi`/`windows`), macOS (`cocoa`), Linux (`gtk`/`x11`). Export through FFI to Swift. Document usage in `Docs/PlatformAPI.md`.
  - **Completed:** 2026-03-28. Created `rust/raven-core/src/platform_api.rs` with clipboard (get/set), file dialogs (open/save), and OS notifications. Platform backends: PowerShell (Windows), pbcopy/osascript (macOS), xclip/zenity/notify-send (Linux). Swift wrapper: `Sources/Raven/Platform/PlatformAPI.swift` with `RavenPlatform` enum. C header updated with all FFI declarations.

- `[x]` **Complex App Feasibility Audit**
  - **Problem:** Unclear if Raven can support modern, feature‑rich apps like Arc Browser, Discord, DaVinci Resolve.
  - **Solution:** Conduct a gap analysis: list required features (web engine, rich text chat, video playback, GPU‑accelerated effects). Identify missing subsystems (WebView, audio/video pipelines, multi‑window management). Propose incremental roadmap: integrate a WebView (e.g., `WebKitGTK`/`WebView2`), add audio via `SDL_mixer` or `PortAudio`, support multiple windows, implement GPU‑based video decoding. Document findings in `Docs/FeasibilityAudit.md`.
  - **Completed:** 2026-03-28. `Docs/FeasibilityAudit.md` documents required features, missing subsystems, 3‑phase incremental roadmap, and risk mitigations.

---

*Use this `task.md` as the source of truth for the upcoming sprint. Mark items as `[/]` when work begins and `[x]` when completed.*

- `[ ]` **BUG-001: Insecure `getenv` Usage**
  - **Severity:** High
  - **Type:** Security Vulnerability
  - **Description:** The codebase uses `getenv` to read environment variables, which is not thread-safe and is deprecated on Windows. This can lead to race conditions and unpredictable behavior.
  - **Location:** 
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\VulkanHelpers.swift:61`
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\VulkanPipeline.swift:29`
  - **Observed Behavior:** The application compiles with warnings about deprecated `getenv` usage.
  - **Expected Behavior:** The application should use thread-safe and modern APIs to access environment variables.
  - **Proposed Solution:** Replace `getenv` with `ProcessInfo.processInfo.environment` in Swift. This is a thread-safe way to access environment variables.

- `[ ]` **BUG-002: Unhandled Errors in File Operations**
  - **Severity:** Medium
  - **Type:** Logical Error
  - **Description:** The `readFileBytes` function in `FontManager.swift` returns `nil` on failure but does not provide any specific error information, making it difficult to debug file-related issues.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\FontManager.swift:50`
  - **Observed Behavior:** The application prints a generic error message to the console when a font file cannot be read.
  - **Expected Behavior:** The function should throw a specific error (e.g., `FontError.fileNotFound`) that can be caught and handled by the caller.
  - **Proposed Solution:** Modify `readFileBytes` to throw a `FontError` on failure, and update the call sites in `FontManager.swift` to handle these errors gracefully.

- `[ ]` **BUG-003: Naive Atlas Packing Algorithm**
  - **Severity:** Medium
  - **Type:** Performance Issue
  - **Description:** The `packGlyph` function in `FontManager.swift` uses a simple row-based packing algorithm that can lead to wasted space in the texture atlas, especially when dealing with glyphs of varying sizes.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\FontManager.swift:401`
  - **Observed Behavior:** The texture atlas grows larger than necessary, leading to increased memory usage and more frequent reallocations.
  - **Expected Behavior:** The atlas packing algorithm should be more efficient, using techniques like bin packing to minimize wasted space.
  - **Proposed Solution:** Replace the current algorithm with a more advanced one, such as Skyline or MaxRects, to improve atlas packing efficiency.

- `[ ]` **BUG-004: Lack of Comprehensive Tests**
  - **Severity:** High
  - **Type:** Functional Deviation
  - **Description:** The project lacks a dedicated test suite, making it difficult to verify the correctness of new features and preventing regressions.
  - **Location:** N/A
  - **Observed Behavior:** No tests are run when `swift test` or `cargo test` is executed.
  - **Expected Behavior:** The project should have a comprehensive suite of unit, integration, and end-to-end tests.
  - **Proposed Solution:** Create a `Tests` directory with separate test targets for the Swift and Rust codebases. Add tests for critical components like the layout engine, view resolver, and platform APIs.

- `[ ]` **BUG-005: Forced Unwrapping in `RavenApp.swift`**
  - **Severity:** High
  - **Type:** Runtime Exception
  - **Description:** The `RavenApp.swift` file contains several instances of forced unwrapping, which can lead to runtime crashes if the optional values are `nil`.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\RavenApp.swift`
  - **Observed Behavior:** The application may crash unexpectedly if certain resources (e.g., SDL window, Vulkan instance) cannot be initialized.
  - **Expected Behavior:** The application should handle `nil` values gracefully, either by providing a fallback or by throwing an error.
  - **Proposed Solution:** Replace all forced unwraps with `guard let` or `if let` statements to safely unwrap optionals.

- `[ ]` **BUG-006: Inefficient String Concatenation in `HotReload.swift`**
  - **Severity:** Low
  - **Type:** Performance Issue
  - **Description:** The `watchLoop` function in `HotReload.swift` uses string concatenation inside a loop to build the log message. This can be inefficient for a large number of changes.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\HotReload.swift:186`
  - **Observed Behavior:** The hot reload process may be slower than necessary when many files are changed at once.
  - **Expected Behavior:** The log message should be constructed more efficiently.
  - **Proposed Solution:** Use string interpolation or a `TextOutputStream` to build the log message more efficiently.

- `[ ]` **BUG-007: Potential Race Condition in `StateTracker.swift`**
  - **Severity:** High
  - **Type:** Logical Error
  - **Description:** The `dirty` flag in `StateTracker.swift` is not always accessed within the lock, which can lead to race conditions in a multi-threaded environment.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\State.swift:207`
  - **Observed Behavior:** The UI may not update correctly if multiple threads modify the state at the same time.
  - **Expected Behavior:** All access to the `dirty` flag should be protected by a lock.
  - **Proposed Solution:** Ensure that all reads and writes to the `dirty` flag are performed within the `lock.withLock` block.

- `[ ]` **BUG-008: Hardcoded Paths in `FontManager.swift`**
  - **Severity:** Medium
  - **Type:** Logical Error
  - **Description:** The `loadDefaultFont` function in `FontManager.swift` uses hardcoded relative paths to find the default font, which can break if the application is run from a different directory.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\FontManager.swift:93`
  - **Observed Behavior:** The default font may fail to load if the application's working directory is not what the code expects.
  - **Expected Behavior:** The application should be able to locate the default font regardless of the working directory.
  - **Proposed Solution:** Use a more robust method to locate the bundled resources, such as `Bundle.main.path(forResource:ofType:)`.

- `[ ]` **BUG-009: Missing `Sendable` Conformance**
  - **Severity:** Medium
  - **Type:** Logical Error
  - **Description:** Several classes, such as `VulkanRenderer` and `HotReloadEngine`, are not marked as `Sendable`, which can cause data races and other concurrency issues with Swift 6's strict concurrency model.
  - **Location:** 
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\VulkanRenderer.swift:6`
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\HotReload.swift:36`
  - **Observed Behavior:** The application may experience data races and other concurrency-related bugs.
  - **Expected Behavior:** All classes that are passed between concurrency domains should conform to `Sendable`.
  - **Proposed Solution:** Add `@unchecked Sendable` conformance to these classes after verifying that they are thread-safe.

- `[ ]` **BUG-010: Rust FFI Linker Errors on Windows**
  - **Severity:** High
  - **Type:** Build Error
  - **Description:** The `raven-core` Rust crate fails to build on Windows due to linker errors. The build is missing the necessary Windows libraries for clipboard operations.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\rust\raven-core\src\clipboard.rs`
  - **Observed Behavior:** The `cargo test` and `cargo build` commands fail with linker errors.
  - **Expected Behavior:** The Rust crate should build successfully on Windows.
  - **Proposed Solution:** Add a build script (`build.rs`) to the `raven-core` crate that links against the necessary Windows libraries (e.g., `user32`).

- `[ ]` **BUG-011: Use of `print` for Logging**
  - **Severity:** Low
  - **Type:** Functional Deviation
  - **Description:** The codebase uses `print` for logging in several places, which bypasses the structured logging system provided by `RavenLogger`.
  - **Location:** 
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\RavenApp.swift`
    - `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\FontManager.swift`
  - **Observed Behavior:** Log messages are not consistently formatted and cannot be filtered by severity.
  - **Expected Behavior:** All log messages should be sent through the `RavenLogger` to ensure consistent formatting and filtering.
  - **Proposed Solution:** Replace all instances of `print` with the appropriate `RavenLogger` method (e.g., `RavenLogger.info`, `RavenLogger.error`).

- `[ ]` **BUG-012: Inefficient Layout Pass**
  - **Severity:** Medium
  - **Type:** Performance Issue
  - **Description:** The layout engine performs a full layout pass on the entire view hierarchy even when only a small part of the UI has changed.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\LayoutEngine.swift`
  - **Observed Behavior:** The application's performance may degrade as the complexity of the UI increases.
  - **Expected Behavior:** The layout engine should only re-compute the layout for the parts of the view hierarchy that have been affected by a state change.
  - **Proposed Solution:** Implement a more granular dependency tracking system that allows the layout engine to identify which nodes need to be re-laid out.

- `[ ]` **BUG-013: Redundant Code in `platform_api.rs`**
  - **Severity:** Low
  - **Type:** Logical Error
  - **Description:** The `platform_api.rs` and `clipboard.rs` files contain duplicate code for clipboard operations.
  - **Location:** 
    - `c:\Users\woisr\OneDrive\Desktop\Raven\rust\raven-core\src\platform_api.rs`
    - `c:\Users\woisr\OneDrive\Desktop\Raven\rust\raven-core\src\clipboard.rs`
  - **Observed Behavior:** The codebase is larger and more difficult to maintain than necessary.
  - **Expected Behavior:** The clipboard-related code should be defined in a single place and reused.
  - **Proposed Solution:** Remove the duplicate clipboard code from `platform_api.rs` and have it call the functions in `clipboard.rs` instead.

- `[ ]` **BUG-014: Unsafe Pointer Usage in `VulkanRenderer.swift`**
  - **Severity:** High
  - **Type:** Security Vulnerability
  - **Description:** The `VulkanRenderer.swift` file uses `SDL_strdup` to duplicate C strings, but it does not free the allocated memory, leading to memory leaks.
  - **Location:** `c:\Users\woisr\OneDrive\Desktop\Raven\Sources\Raven\Renderer\VulkanRenderer.swift`
  - **Observed Behavior:** The application's memory usage will grow over time, which can lead to performance issues and crashes.
  - **Expected Behavior:** All manually allocated memory should be freed when it is no longer needed.
  - **Proposed Solution:** Use a `defer` block to ensure that the memory allocated by `SDL_strdup` is freed with `SDL_free`.
