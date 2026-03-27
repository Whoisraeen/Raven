# Windows SDL Hello

Minimal Windows bootstrap for Raven Phase 1.

This package verifies:

- Swift can build a native executable on Windows
- SDL3 can create a native desktop window
- Vulkan can create a swapchain for that SDL window
- The app can clear the window to a solid color and process quit, keyboard, and mouse events

## Run

From this directory:

```powershell
.\run.ps1
```

The window auto-closes after a few seconds so the verification run can complete unattended.
