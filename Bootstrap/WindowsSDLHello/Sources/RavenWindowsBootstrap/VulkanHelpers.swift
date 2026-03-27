import CSDL3
import CVulkan
import Foundation

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

// MARK: - Error Handling

@inline(__always)
func currentSDLError() -> String {
    String(cString: SDL_GetError())
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func vkCheck(_ result: VkResult, _ context: String) {
    if result != VK_SUCCESS {
        fail("\(context) failed with VkResult \(result.rawValue)")
    }
}

// MARK: - Vertex Data

struct QuadVertex {
    var posX: Float
    var posY: Float
    var r: Float
    var g: Float
    var b: Float
    var a: Float

    init(_ x: Float, _ y: Float, _ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        self.posX = x
        self.posY = y
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

struct Quad {
    var x: Float
    var y: Float
    var width: Float
    var height: Float
    var r: Float
    var g: Float
    var b: Float
    var a: Float

    init(x: Float, y: Float, width: Float, height: Float, r: Float, g: Float, b: Float, a: Float = 1.0) {
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
    func vertices() -> [QuadVertex] {
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
    // Look for SPIR-V files relative to the executable, then in the Shaders directory
    let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    
    let searchPaths = [
        executableURL.appendingPathComponent(filename).path,
        executableURL.appendingPathComponent("Shaders/\(filename)").path,
        // Relative to package root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // RavenWindowsBootstrap
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // WindowsSDLHello
            .appendingPathComponent("Shaders/\(filename)").path
    ]

    for path in searchPaths {
        if FileManager.default.fileExists(atPath: path) {
            guard let data = FileManager.default.contents(atPath: path) else {
                fail("Failed to read SPIR-V file at \(path)")
            }
            return [UInt8](data)
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

        return VulkanBuffer(buffer: buffer, memory: memory, size: size)
    }

    func upload<T>(device: VkDevice, data: [T]) {
        var mapped: UnsafeMutableRawPointer?
        vkCheck(vkMapMemory(device, memory, 0, size, 0, &mapped), "vkMapMemory")
        guard let mapped else { fail("vkMapMemory returned nil") }

        data.withUnsafeBytes { srcBuffer in
            mapped.copyMemory(from: srcBuffer.baseAddress!, byteCount: srcBuffer.count)
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
