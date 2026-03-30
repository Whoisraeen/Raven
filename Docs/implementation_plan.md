# Vulkan Renderer Audit & Remediation Plan

This document outlines the bugs and issues discovered during the audit of the four core Vulkan rendering modules (`VulkanRenderer`, `VulkanPipeline`, `TextRenderer`, and `ImageRenderer`) and proposes a concrete implementation plan to resolve them before production launch.

## User Review Required

> [!WARNING]
> The audit discovered a critical memory leak that occurs every time the application window is resized, as well as a visual clipping bug that causes text and images to "bleed" out of scroll views. 
> Please review the proposed fixes below.

## Bugs Discovered

1. **`VKTimer` Swapchain Handle Memory Leak (`VulkanRenderer.swift`)**
   - **Issue**: In `recreateSwapchain()`, the existing swapchain handle is passed as `oldSwapchain` into `vkCreateSwapchainKHR` to allow the graphics driver to reuse memory optimizations. However, the Vulkan specification mandates that the application *must still manually destroy the old swapchain* (`vkDestroySwapchainKHR`) even if creation succeeds. Currently, Raven just overwrites the handle variable, continuously leaking a `VkSwapchainKHR` handle every time the user drags the window.
2. **Missing Dynamic Scissor Support (`TextRenderer.swift` & `ImageRenderer.swift`)**
   - **Issue**: `TextDrawCommand` and `ImageDrawCommand` explicitly accept a `.clipRect` property (intended for scroll views, sidebars, masks). However, when `TextRenderer.recordDraw` and `ImageRenderer.recordDraw` are executed, they ignore this property entirely. They never invoke `vkCmdSetScissor` prior to their `vkCmdDraw` calls. As a result, all geometric primitives (backgrounds, lines) are correctly clipped, but text and image components always overlap UI boundaries.
3. **Improper Vertex Batching for Text (`TextRenderer.swift`)**
   - **Issue**: `TextRenderer` compiles all text on the screen into a single vertex array and issues exactly one `vkCmdDraw` call for all text. Since different labels will inevitably have different clipping rectangles, we cannot issue a single draw call. We must partition the draw calls based on the active `ClipRect`.

---

## Proposed Changes

### Vulkan Renderer

#### [MODIFY] `VulkanRenderer.swift`
- In `recreateSwapchain()`, explicitly cache the `oldSwapchain` handle, and invoke `vkDestroySwapchainKHR(device, oldSwapchain, nil)` *after* successfully creating `newSwapchain`.
- Expose the helper function `clipRectToVkRect2D` so that the Text and Image renderers can utilize it to parse Swift `ClipRect` structures into Vulkan scissor structures.

### Image Renderer

#### [MODIFY] `ImageRenderer.swift`
- In `recordDraw()`, extract the active `swapchainExtent` logic to compute the `fullScissor` default viewport bounds.
- During the `commands` iteration loop, invoke `vkCmdSetScissor` dynamically using the current command's `clipRect` before the `vkCmdDraw` execution.
- Re-apply the `fullScissor` once the command loop concludes to avoid corrupting pipeline state for remaining render tasks.

### Text Renderer

#### [MODIFY] `TextRenderer.swift`
- Completely overhaul `recordDraw()` to support Scissor batching (similar to the logic that protects primitive `Quads`).
- Because a single `TextDrawCommand` outputs an unpredictable number of vertices depending on string length, we will have `generateVertices` return a tuple array mapping each generated chunk of vertices to its respective `ClipRect`.
- We will iterate over the vertices, splitting the `vkCmdDraw` commands every time the `ClipRect` changes, injecting `vkCmdSetScissor` to properly clip the typography.

## Open Questions

None at this moment. The fixes are deterministic Vulkan C-API usages and have no upstream effects on the declarative Swift macros.

## Verification Plan

### Automated Tests
- Boot the OS/UI shell and spam dragging the window size. Monitor memory footprint locally.

### Manual Verification
- Render a `ScrollView` containing `Text` and `Image` blocks, scrolling up and down to visually confirm that the text cleanly clips at the boundaries of the Scrollable View region rather than bleeding onto the titlebar.
