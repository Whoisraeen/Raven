// swift-tools-version: 6.0
import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let sdlIncludePath = packageRoot
    .appendingPathComponent("Sources/CSDL3")
    .standardizedFileURL
    .path
let sdlLibraryPath = packageRoot
    .appendingPathComponent("../../vendor/SDL3/SDL3-3.4.2/lib/x64")
    .standardizedFileURL
    .path
let vulkanSDKBasePath = "C:/VulkanSDK"
let vulkanSDKRoot = (try? FileManager.default
    .contentsOfDirectory(at: URL(fileURLWithPath: vulkanSDKBasePath), includingPropertiesForKeys: nil)
    .filter { $0.hasDirectoryPath }
    .sorted { $0.lastPathComponent > $1.lastPathComponent }
    .first)?
    .standardizedFileURL
    .path
let vulkanIncludePath = (vulkanSDKRoot.map { "\($0)/Include" }) ?? "\(vulkanSDKBasePath)/Include"
let vulkanLibraryPath = (vulkanSDKRoot.map { "\($0)/Lib" }) ?? "\(vulkanSDKBasePath)/Lib"

let package = Package(
    name: "WindowsSDLHello",
    products: [
        .executable(
            name: "RavenWindowsBootstrap",
            targets: ["RavenWindowsBootstrap"]
        )
    ],
    targets: [
        .systemLibrary(
            name: "CSDL3"
        ),
        .systemLibrary(
            name: "CVulkan"
        ),
        .executableTarget(
            name: "RavenWindowsBootstrap",
            dependencies: ["CSDL3", "CVulkan"],
            swiftSettings: [
                .unsafeFlags([
                    "-Xcc",
                    "-I\(sdlIncludePath)"
                ]),
                .unsafeFlags([
                    "-Xcc",
                    "-I\(vulkanIncludePath)"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "/LIBPATH:\(sdlLibraryPath)"
                ]),
                .unsafeFlags([
                    "-Xlinker",
                    "/LIBPATH:\(vulkanLibraryPath)"
                ])
            ]
        )
    ]
)
