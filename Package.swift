// swift-tools-version: 6.0
import PackageDescription

// MARK: - Platform-Specific Paths & Settings
//
// Foundation is intentionally NOT imported here to avoid toolchain/SDK
// version mismatch issues on Windows. All paths use string manipulation.

#if os(macOS)

// Homebrew: /opt/homebrew on Apple Silicon, /usr/local on Intel
// Detect at build time isn't possible without Foundation; default to /opt/homebrew
// and let users override via RAVEN_HOMEBREW_PREFIX env if needed.
let homebrewPrefix = "/opt/homebrew"

let sdlLibraryPath = "\(homebrewPrefix)/lib"
let vulkanIncludePath = "\(homebrewPrefix)/include"
let vulkanLibraryPath = "\(homebrewPrefix)/lib"
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

// SDL3: vendored in the repo
let sdlLibraryPath = "vendor/SDL3/SDL3-3.4.2/lib/x64"

// Vulkan SDK: auto-detect from C:/VulkanSDK or use VULKAN_SDK env var
let vulkanSDKEnv = Context.environment["VULKAN_SDK"]
let vulkanIncludePath = vulkanSDKEnv.map { "\($0)/Include" } ?? "C:/VulkanSDK/1.4.341.1/Include"
let vulkanLibraryPath = vulkanSDKEnv.map { "\($0)/Lib" } ?? "C:/VulkanSDK/1.4.341.1/Lib"

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
]

#elseif os(Linux)

let sdlLibraryPath = "/usr/lib"
let vulkanIncludePath = "/usr/include"
let vulkanLibraryPath = "/usr/lib"
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
            exclude: ["Resources", "Shaders"],
            swiftSettings: platformSwiftSettings,
            linkerSettings: ravenLinkerSettings
        ),
        .executableTarget(
            name: "RavenDemo",
            dependencies: ["Raven"],
            swiftSettings: platformSwiftSettings,
            linkerSettings: demoLinkerSettings
        )
    ]
)
