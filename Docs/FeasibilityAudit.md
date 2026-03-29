# Feasibility Audit – Extending Raven for Modern Apps

## 1. Required Features for Target Applications

| Feature | Why it is needed | Typical use‑case in target apps |
|---------|------------------|--------------------------------|
| **Web Engine / WebView** | Render rich web content, embed web‑based UIs, and provide extensions. | Arc Browser – full Chromium‑style browsing; Discord – embedded help pages and OAuth flows. |
| **Rich Text Chat** | Real‑time messaging with formatting, emojis, mentions, and markdown. | Discord – chat channels with rich formatting and media previews. |
| **Video Playback** | Decode and display video streams (e.g., tutorials, user‑generated clips). | Discord – video calls and embedded video previews; DaVinci Resolve – preview of video timelines. |
| **GPU‑Accelerated Effects** | Apply shaders, transitions, and compositing at high frame‑rates. | DaVinci Resolve – color‑grading, effects pipelines; Arc Browser – CSS‑based animations and WebGL. |
| **Multi‑Window Management** | Allow multiple independent windows (e.g., separate chat, settings, video preview). | Discord – separate pop‑out chat windows; DaVinci Resolve – multiple monitor output. |
| **Audio Pipeline** | Playback and capture of audio streams (voice chat, UI sounds). | Discord – voice chat; DaVinci Resolve – audio track editing. |

## 2. Missing Sub‑systems in the Current Raven Framework

| Missing Sub‑system | Current Gap | Impact |
|--------------------|-------------|--------|
| **WebView / Embedded Browser** | No integration with any web rendering engine. | Cannot display web content or build a full‑featured browser. |
| **Audio Pipeline** | Only basic SDL event handling; no audio playback or capture. | No voice chat, media playback, or UI sound effects. |
| **Video Decoding / Playback** | No decoder; only static image rendering via `ImageDrawCommand`. | No ability to play video files or streams. |
| **Multi‑Window Support** | Single SDL window created at startup. | Cannot pop‑out UI components or support multi‑monitor workflows. |
| **GPU‑Based Video Decoding** | Vulkan renderer only handles quads/text; no video‑specific pipelines. | Inefficient CPU‑only decoding; no high‑performance video playback. |
| **Web‑Based Rich Text Rendering** | Text rendering is limited to SDF glyphs; no markdown or rich formatting. | Chat UI would be plain text only. |

## 3. Incremental Roadmap

### Phase 1 – Foundations (0‑2 months)
1. **Add a WebView abstraction**
   - Create a `WebView` Swift protocol with `load(url:)`, `evaluateJS(_:)`, and `snapshot()`.
   - Implement platform‑specific back‑ends:
     - Windows: `WebView2` (Chromium‑based) via the `windows` crate.
     - macOS: `WKWebView` via the `cocoa` crate.
     - Linux: `WebKitGTK` (or `QtWebEngine` if needed).
   - Expose the view as a `View` subclass that renders to a texture which can be used by the existing Vulkan pipeline.
2. **Introduce an audio layer**
   - Add `SDL_mixer` as a dependency in the Rust core for simple playback of OGG/MP3/WAV.
   - Provide a Swift wrapper `AudioEngine.play(sound:)` and `AudioEngine.record()`.
   - Ensure the audio thread runs independently of the render loop.
3. **Refactor window creation**
   - Abstract SDL window creation behind a `WindowManager` protocol.
   - Implement a minimal multi‑window manager that can spawn additional SDL windows and expose their IDs to Swift.

### Phase 2 – Media & Rich UI (2‑4 months)
1. **Video decoding pipeline**
   - Integrate `ffmpeg` (via `ffmpeg‑sys` crate) to decode video frames to NV12/YUV.
   - Upload decoded frames to a Vulkan texture each frame (GPU‑based upload).
   - Add a `VideoView` that consumes a video source URL/path and renders via the existing `RenderCollector`.
2. **Rich text chat component**
   - Extend `Text` view to support markdown parsing (use `cmark` library) and emoji rendering (glyph atlas extensions).
   - Provide a `ChatMessage` view that composes styled text, inline images, and reactions.
3. **GPU‑accelerated effects framework**
   - Define a `ShaderEffect` protocol with a custom fragment shader.
   - Allow chaining of effects on any `View` (e.g., blur, color‑grade, transition).
   - Provide a sample effect (Gaussian blur) to validate the pipeline.

### Phase 3 – Full‑Featured Application Stack (4‑6 months)
1. **Multi‑window UI**
   - Build a window manager that tracks focus, z‑order, and drag‑drop between windows.
   - Expose Swift APIs to create new windows with custom title bars (using the `WindowManager` from Phase 1).
2. **Audio‑Video sync & capture**
   - Add `PortAudio` (or `cpal`) for low‑latency audio capture.
   - Synchronize audio playback with video frames for smooth playback.
3. **Integrate WebView with UI**
   - Allow embedding a `WebView` inside any `View` hierarchy.
   - Support off‑screen rendering to a texture for compositing with other UI elements.
4. **Performance & Stability**
   - Implement profiling hooks (already in the task list) to monitor frame‑time, decode latency, and memory usage.
   - Add automated integration tests for each new subsystem.

## 4. Risks & Mitigations
- **Platform divergence** – WebView APIs differ significantly. Mitigation: isolate each implementation behind a common Swift protocol and keep platform‑specific code in separate Rust crates.
- **GPU memory pressure** – Video textures can be large. Mitigation: use tiled streaming and recycle textures via a pool.
- **Audio‑video sync** – Clock drift between decoding and rendering. Mitigation: use a shared high‑resolution timer (e.g., `mach_absolute_time` / `QueryPerformanceCounter`).
- **Complexity creep** – Adding many subsystems could bloat the codebase. Mitigation: enforce modular boundaries and keep each feature behind a clearly defined interface.

---

*This document serves as the baseline feasibility audit. Each bullet point can be turned into a task in `Docs/task.md` for sprint planning.*
