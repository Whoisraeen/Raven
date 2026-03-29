// swift-tools-version: 6.3
import PackageDescription

// MARK: - Platform-Specific Paths & Settings
//
// Foundation is intentionally NOT imported here to avoid toolchain/SDK
// version mismatch issues on Windows. All paths use string manipulation.

#if os(macOS)

// Homebrew: /opt/homebrew on Apple Silicon, /usr/local on Intel
// Override via RAVEN_HOMEBREW_PREFIX env var if needed.
let homebrewPrefix = Context.environment["RAVEN_HOMEBREW_PREFIX"] ?? "/opt/homebrew"

let sdlLibraryPath = Context.environment["RAVEN_SDL_LIB"] ?? "\(homebrewPrefix)/lib"
let vulkanIncludePath = Context.environment["VULKAN_SDK"].map { "\($0)/include" } ?? "\(homebrewPrefix)/include"
let vulkanLibraryPath = Context.environment["VULKAN_SDK"].map { "\($0)/lib" } ?? "\(homebrewPrefix)/lib"
let ravenCoreLibPath = "rust/raven-core/target/release"

let sdlIncludePath = "Sources/CSDL3"

let platformSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(sdlIncludePath)"]),
    .unsafeFlags(["-Xcc", "-I\(vulkanIncludePath)"]),
]

let ravenLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(sdlLibraryPath)"]),
    .unsafeFlags(["-L\(vulkanLibraryPath)"]),
    .unsafeFlags(["-L\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan"),
    .linkedLibrary("raven_core"),
]

let demoLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(sdlLibraryPath)"]),
    .unsafeFlags(["-L\(vulkanLibraryPath)"]),
    .unsafeFlags(["-L\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan"),
    .linkedLibrary("raven_core"),
]

#elseif os(Windows)

// SDL3: vendored in the repo — detect architecture
// SPM doesn't expose arch, so check for ARM64 vendor path first, fallback to x64
let sdlArm64Path = "vendor/SDL3/SDL3-3.4.2/lib/ARM64"
let sdlX64Path = "vendor/SDL3/SDL3-3.4.2/lib/x64"
// Default to x64; users on ARM64 should set RAVEN_SDL_LIB env var
let sdlLibraryPath = Context.environment["RAVEN_SDL_LIB"] ?? sdlX64Path

// Vulkan SDK: require VULKAN_SDK env var (set by Vulkan SDK installer)
let vulkanSDKEnv = Context.environment["VULKAN_SDK"] ?? Context.environment["VK_SDK_PATH"]
let vulkanIncludePath: String
let vulkanLibraryPath: String
if let sdk = vulkanSDKEnv {
    vulkanIncludePath = "\(sdk)/Include"
    vulkanLibraryPath = "\(sdk)/Lib"
} else {
    // Emit a build warning — user must set VULKAN_SDK
    vulkanIncludePath = "C:/VulkanSDK/Include"
    vulkanLibraryPath = "C:/VulkanSDK/Lib"
}

// Rust static library
let ravenCoreLibPath = "rust/raven-core/target/release"

let sdlIncludePath = "Sources/CSDL3"

let platformSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(sdlIncludePath)"]),
    .unsafeFlags(["-Xcc", "-I\(vulkanIncludePath)"]),
]

let ravenLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(sdlLibraryPath)"]),
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(vulkanLibraryPath)"]),
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan-1"),
    .linkedLibrary("raven_core"),
    // Rust stdlib dependencies on Windows
    .linkedLibrary("ws2_32"),
    .linkedLibrary("ntdll"),
    .linkedLibrary("userenv"),
    .linkedLibrary("advapi32"),
    .linkedLibrary("bcrypt"),
    // Platform bridge (clipboard, file dialogs)
    .linkedLibrary("user32"),
    .linkedLibrary("ole32"),
    .linkedLibrary("shell32"),
]

let demoLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(sdlLibraryPath)"]),
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(vulkanLibraryPath)"]),
    .unsafeFlags(["-Xlinker", "/LIBPATH:\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan-1"),
    .linkedLibrary("raven_core"),
    // Rust stdlib dependencies on Windows
    .linkedLibrary("ws2_32"),
    .linkedLibrary("ntdll"),
    .linkedLibrary("userenv"),
    .linkedLibrary("advapi32"),
    .linkedLibrary("bcrypt"),
    // Platform bridge (clipboard, file dialogs)
    .linkedLibrary("user32"),
    .linkedLibrary("ole32"),
    .linkedLibrary("shell32"),
]

#elseif os(Linux)

// Linux: use standard system paths or env overrides
// Install deps: sudo apt install libsdl3-dev libvulkan-dev vulkan-tools
let sdlLibraryPath = Context.environment["RAVEN_SDL_LIB"] ?? "/usr/lib/x86_64-linux-gnu"
let vulkanIncludePath = Context.environment["VULKAN_SDK"].map { "\($0)/include" } ?? "/usr/include"
let vulkanLibraryPath = Context.environment["VULKAN_SDK"].map { "\($0)/lib" } ?? "/usr/lib/x86_64-linux-gnu"
let ravenCoreLibPath = "rust/raven-core/target/release"

let sdlIncludePath = "Sources/CSDL3"

let platformSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(sdlIncludePath)"]),
    .unsafeFlags(["-Xcc", "-I\(vulkanIncludePath)"]),
]

let ravenLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(sdlLibraryPath)"]),
    .unsafeFlags(["-L\(vulkanLibraryPath)"]),
    .unsafeFlags(["-L\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan"),
    .linkedLibrary("raven_core"),
]

let demoLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(sdlLibraryPath)"]),
    .unsafeFlags(["-L\(vulkanLibraryPath)"]),
    .unsafeFlags(["-L\(ravenCoreLibPath)"]),
    .linkedLibrary("SDL3"),
    .linkedLibrary("vulkan"),
    .linkedLibrary("raven_core"),
]

#endif

// MARK: - Package Definition

let package = Package(
    name: "Raven",
    products: [
        .library(
            name: "Raven",
            targets: ["Raven"]
        ),
        .executable(
            name: "RavenDemo",
            targets: ["RavenDemo"]
        )
    ],
    targets: [
        .systemLibrary(
            name: "CSDL3"
        ),
        .systemLibrary(
            name: "CVulkan"
        ),
        .systemLibrary(
            name: "CRavenCore"
        ),
        .target(
            name: "CSTBTrueType",
            path: "Sources/CSTBTrueType",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CSTBImage",
            path: "Sources/CSTBImage",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Raven",
            dependencies: ["CSDL3", "CVulkan", "CSTBTrueType", "CSTBImage", "CRavenCore"],
            exclude: ["Shaders"],
            resources: [.process("Resources")],
            swiftSettings: platformSwiftSettings,
            linkerSettings: ravenLinkerSettings
        ),
        .executableTarget(
            name: "RavenDemo",
            dependencies: ["Raven"],
            swiftSettings: platformSwiftSettings,
            linkerSettings: demoLinkerSettings
        ),
        .testTarget(
            name: "RavenTests",
            dependencies: ["Raven"],
            swiftSettings: platformSwiftSettings,
            linkerSettings: demoLinkerSettings
        )
    ]
)
