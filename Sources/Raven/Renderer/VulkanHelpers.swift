import CSDL3
import CVulkan

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Constants

let sdlWindowResizableFlag: SDL_WindowFlags = 0x0000000000000020
let sdlWindowVulkanFlag: SDL_WindowFlags = 0x0000000010000000

let vkQueueGraphicsBit: VkQueueFlags = 0x00000001
let vkImageUsageColorAttachmentBit: VkImageUsageFlags = 0x00000010
let vkImageUsageTransferDstBit: VkImageUsageFlags = 0x00000002
let vkImageAspectColorBit: VkImageAspectFlags = 0x00000001
let vkAccessColorAttachmentWriteBit: VkAccessFlags = 0x00000100
let vkAccessTransferWriteBit: VkAccessFlags = 0x00001000
let vkPipelineStageTopOfPipeBit: VkPipelineStageFlags = 0x00000001
let vkPipelineStageColorAttachmentOutputBit: VkPipelineStageFlags = 0x00000400
let vkPipelineStageTransferBit: VkPipelineStageFlags = 0x00001000
let vkPipelineStageBottomOfPipeBit: VkPipelineStageFlags = 0x00002000
let vkCommandPoolResetCommandBufferBit: VkCommandPoolCreateFlags = 0x00000002
let vkCommandBufferOneTimeSubmitBit: VkCommandBufferUsageFlags = 0x00000001
let vkFenceCreateSignaledBit: VkFenceCreateFlags = 0x00000001
let vkTrueValue: VkBool32 = 1
let vkQueueFamilyIgnored = UInt32.max
let vkApiVersion1_0: UInt32 = 1 << 22
let vkShaderStageVertexBit: VkShaderStageFlags = 0x00000001
let vkShaderStageFragmentBit: VkShaderStageFlags = 0x00000010
let vkDynamicStateViewport = VkDynamicState(rawValue: 0)
let vkDynamicStateScissor = VkDynamicState(rawValue: 1)
let vkColorComponentRBit: VkColorComponentFlags = 0x00000001
let vkColorComponentGBit: VkColorComponentFlags = 0x00000002
let vkColorComponentBBit: VkColorComponentFlags = 0x00000004
let vkColorComponentABit: VkColorComponentFlags = 0x00000008
let vkColorComponentAllBits: VkColorComponentFlags = 0x0000000F

#if os(macOS)
let vkInstanceCreateEnumeratePortabilityBitKHR: VkInstanceCreateFlags = 0x00000001
#endif

// MARK: - Error Handling

@inline(__always)
func currentSDLError() -> String {
    String(cString: SDL_GetError())
}

func fail(_ message: String) -> Never {
    print("[FATAL] \(message)")
    exit(1)
}

func vkCheck(_ result: VkResult, _ context: String) {
    if result != VK_SUCCESS {
        fail("\(context) failed with VkResult \(result.rawValue)")
    }
}

// MARK: - Path Helpers (Foundation-free)

/// Get the parent directory of a path (everything before the last separator).
func parentDirectory(of path: String) -> String {
    // Normalize: handle both / and \ separators
    let chars = Array(path)
    var lastSep = -1
    for i in stride(from: chars.count - 2, through: 0, by: -1) {
        if chars[i] == "/" || chars[i] == "\\" {
            lastSep = i
            break
        }
    }
    if lastSep <= 0 { return "." }
    return String(chars[..<lastSep])
}

/// Join a directory path and a filename/subpath.
func joinPath(_ base: String, _ component: String) -> String {
    if base.isEmpty { return component }
    let sep: Character = base.contains("\\") ? "\\" : "/"
    let trimmedBase = base.hasSuffix("/") || base.hasSuffix("\\")
        ? String(base.dropLast()) : base
    return "\(trimmedBase)\(sep)\(component)"
}

/// Check if a file exists at the given path using SDL's file I/O.
func fileExists(atPath path: String) -> Bool {
    guard let io = SDL_IOFromFile(path, "rb") else { return false }
    _ = SDL_CloseIO(io)
    return true
}

/// Read all bytes from a file using SDL's file I/O.
func readFileBytes(atPath path: String) -> [UInt8]? {
    guard let io = SDL_IOFromFile(path, "rb") else { return nil }
    defer { _ = SDL_CloseIO(io) }

    let size = SDL_GetIOSize(io)
    guard size > 0 else { return nil }

    var buffer = [UInt8](repeating: 0, count: Int(size))
    let read = SDL_ReadIO(io, &buffer, Int(size))
    guard read == Int(size) else { return nil }
    return buffer
}

// MARK: - Vertex Data

public struct QuadVertex {
    public var posX: Float
    public var posY: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(_ x: Float, _ y: Float, _ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        self.posX = x
        self.posY = y
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

public struct Quad {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(x: Float, y: Float, width: Float, height: Float, r: Float, g: Float, b: Float, a: Float = 1.0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Generate 6 vertices (2 triangles) for this quad
    public func vertices() -> [QuadVertex] {
        let left = x
        let right = x + width
        let top = y
        let bottom = y + height

        return [
            // Triangle 1: top-left, bottom-left, bottom-right
            QuadVertex(left, top, r, g, b, a),
            QuadVertex(left, bottom, r, g, b, a),
            QuadVertex(right, bottom, r, g, b, a),
            // Triangle 2: top-left, bottom-right, top-right
            QuadVertex(left, top, r, g, b, a),
            QuadVertex(right, bottom, r, g, b, a),
            QuadVertex(right, top, r, g, b, a),
        ]
    }
}

// MARK: - Queue Family Discovery

func findGraphicsPresentQueueFamily(_ device: VkPhysicalDevice?, _ surface: VkSurfaceKHR?) -> UInt32? {
    var familyCount: UInt32 = 0
    vkGetPhysicalDeviceQueueFamilyProperties(device, &familyCount, nil)

    var families = [VkQueueFamilyProperties](repeating: VkQueueFamilyProperties(), count: Int(familyCount))
    families.withUnsafeMutableBufferPointer { buffer in
        vkGetPhysicalDeviceQueueFamilyProperties(device, &familyCount, buffer.baseAddress)
    }

    for (index, family) in families.enumerated() {
        guard (family.queueFlags & vkQueueGraphicsBit) != 0 else {
            continue
        }

        var presentSupport: VkBool32 = 0
        vkGetPhysicalDeviceSurfaceSupportKHR(device, UInt32(index), surface, &presentSupport)
        if presentSupport == vkTrueValue {
            return UInt32(index)
        }
    }

    return nil
}

// MARK: - SPIR-V Loading

func loadSPIRV(named filename: String) -> [UInt8] {
    let execDir = parentDirectory(of: CommandLine.arguments[0])

    let searchPaths = [
        joinPath(execDir, filename),
        joinPath(execDir, "Shaders/\(filename)"),
        // Relative to this source file (Sources/Raven/Renderer -> Sources/Raven/Shaders)
        joinPath(
            parentDirectory(of: parentDirectory(of: parentDirectory(of: #filePath))),
            "Sources/Raven/Shaders/\(filename)"
        ),
        // Also check Bootstrap shaders
        joinPath(
            parentDirectory(of: parentDirectory(of: parentDirectory(of: #filePath))),
            "Bootstrap/WindowsSDLHello/Shaders/\(filename)"
        ),
    ]

    for path in searchPaths {
        if fileExists(atPath: path) {
            guard let data = readFileBytes(atPath: path) else {
                fail("Failed to read SPIR-V file at \(path)")
            }
            return data
        }
    }

    fail("SPIR-V file \(filename) not found. Searched: \(searchPaths)")
}

// MARK: - Vulkan Buffer Helpers

struct VulkanBuffer {
    var buffer: VkBuffer?
    var memory: VkDeviceMemory?
    var size: VkDeviceSize

    static func create(
        device: VkDevice,
        physicalDevice: VkPhysicalDevice,
        size: VkDeviceSize,
        usage: VkBufferUsageFlags,
        memoryPropertyFlags: VkMemoryPropertyFlags
    ) -> VulkanBuffer {
        var bufferCreateInfo = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: size,
            usage: usage,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )

        var buffer: VkBuffer?
        vkCheck(vkCreateBuffer(device, &bufferCreateInfo, nil, &buffer), "vkCreateBuffer")

        // If memory allocation fails below, clean up the buffer
        var bufferOwned = true
        defer { if bufferOwned { vkDestroyBuffer(device, buffer, nil) } }

        var memoryRequirements = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(device, buffer, &memoryRequirements)

        let memoryTypeIndex = findMemoryType(
            physicalDevice: physicalDevice,
            typeFilter: memoryRequirements.memoryTypeBits,
            properties: memoryPropertyFlags
        )

        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memoryRequirements.size,
            memoryTypeIndex: memoryTypeIndex
        )

        var memory: VkDeviceMemory?
        vkCheck(vkAllocateMemory(device, &allocInfo, nil, &memory), "vkAllocateMemory")
        vkCheck(vkBindBufferMemory(device, buffer, memory, 0), "vkBindBufferMemory")

        bufferOwned = false // Transfer ownership to the returned struct
        return VulkanBuffer(buffer: buffer, memory: memory, size: size)
    }

    func upload<T>(device: VkDevice, data: [T]) {
        var mapped: UnsafeMutableRawPointer?
        vkCheck(vkMapMemory(device, memory, 0, size, 0, &mapped), "vkMapMemory")
        guard let mapped else { fail("vkMapMemory returned nil") }

        data.withUnsafeBytes { srcBuffer in
            guard let base = srcBuffer.baseAddress else { return }
            mapped.copyMemory(from: base, byteCount: srcBuffer.count)
        }

        vkUnmapMemory(device, memory)
    }

    func destroy(device: VkDevice) {
        vkDestroyBuffer(device, buffer, nil)
        vkFreeMemory(device, memory, nil)
    }
}

func findMemoryType(physicalDevice: VkPhysicalDevice, typeFilter: UInt32, properties: VkMemoryPropertyFlags) -> UInt32 {
    var memProperties = VkPhysicalDeviceMemoryProperties()
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties)

    let memoryTypes = withUnsafePointer(to: &memProperties.memoryTypes) { ptr in
        let bound = ptr.withMemoryRebound(to: VkMemoryType.self, capacity: Int(VK_MAX_MEMORY_TYPES)) { $0 }
        return (0..<Int(memProperties.memoryTypeCount)).map { bound[$0] }
    }

    for i in 0..<Int(memProperties.memoryTypeCount) {
        if (typeFilter & (1 << i)) != 0 && (memoryTypes[i].propertyFlags & properties) == properties {
            return UInt32(i)
        }
    }

    fail("Failed to find suitable memory type")
}
