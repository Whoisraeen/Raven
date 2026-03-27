import CSDL3
import CVulkan
import Foundation

// ─── SDL Init ───

guard SDL_Init(SDL_INIT_VIDEO) else {
    fail("SDL_Init failed: \(currentSDLError())")
}

defer {
    SDL_Quit()
}

let windowFlags = sdlWindowResizableFlag | sdlWindowVulkanFlag

guard let window = SDL_CreateWindow("Raven Vulkan Bootstrap", 960, 640, windowFlags) else {
    fail("SDL_CreateWindow failed: \(currentSDLError())")
}

defer {
    SDL_DestroyWindow(window)
}

// ─── Create Renderer ───

let renderer = VulkanRenderer(window: window)

defer {
    renderer.destroy()
}

// ─── Define Test Quads ───

let testQuads: [Quad] = [
    // Large dark panel — centered
    Quad(x: 80, y: 60, width: 800, height: 520, r: 0.14, g: 0.18, b: 0.24),

    // Red rectangle — top-left area
    Quad(x: 120, y: 100, width: 200, height: 140, r: 0.92, g: 0.26, b: 0.21),

    // Green rectangle — top-right area
    Quad(x: 360, y: 100, width: 200, height: 140, r: 0.18, g: 0.80, b: 0.44),

    // Blue rectangle — bottom-left area
    Quad(x: 120, y: 280, width: 200, height: 140, r: 0.20, g: 0.40, b: 0.92),

    // Gold rectangle — bottom-right area
    Quad(x: 360, y: 280, width: 200, height: 140, r: 0.96, g: 0.76, b: 0.18),

    // White rectangle — far right, tall
    Quad(x: 620, y: 100, width: 220, height: 320, r: 0.95, g: 0.95, b: 0.97),

    // Semi-transparent overlay — overlaps red and green
    Quad(x: 260, y: 140, width: 160, height: 80, r: 0.1, g: 0.1, b: 0.1, a: 0.6),
]

// ─── Event Loop ───

let quitEventType = UInt32(SDL_EVENT_QUIT.rawValue)
let keyDownEventType = UInt32(SDL_EVENT_KEY_DOWN.rawValue)

print("Raven Vulkan Bootstrap — Drawing colored rectangles.")
print("Press ESC or close the window to exit.")

var event = SDL_Event()
var isRunning = true

while isRunning {
    while SDL_PollEvent(&event) {
        switch event.type {
        case quitEventType:
            isRunning = false
        case keyDownEventType:
            // Check for ESC key (SDL scancode 41)
            if event.key.scancode == SDL_Scancode(rawValue: 41) {
                isRunning = false
            }
        default:
            break
        }
    }

    if isRunning {
        renderer.drawFrame(quads: testQuads)
    }
}

print("Raven Vulkan Bootstrap exited cleanly.")
