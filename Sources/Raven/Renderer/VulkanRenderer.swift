import CSDL3
import CVulkan


// MARK: - VulkanRenderer

/// Encapsulates the complete Vulkan rendering state.
/// Manages the instance, device, swapchain, graphics pipeline, vertex buffer,
/// and frame synchronization for drawing 2D colored quads.
final class VulkanRenderer: @unchecked Sendable {
    // Core Vulkan objects
    let instance: VkInstance
    let surface: VkSurfaceKHR
    let physicalDevice: VkPhysicalDevice
    let device: VkDevice
    let queue: VkQueue
    let queueFamilyIndex: UInt32

    // Swapchain
    private(set) var swapchain: VkSwapchainKHR?
    private(set) var swapchainImages: [VkImage?]
    private(set) var swapchainFormat: VkFormat
    private(set) var swapchainExtent: VkExtent2D

    // Pipeline
    private(set) var pipeline: VulkanPipeline!

    // Text renderer
    private(set) var textRenderer: TextRenderer!

    // Image renderer
    private(set) var imageRenderer: ImageRenderer!

    // Command resources
    let commandPool: VkCommandPool
    private(set) var commandBuffers: [VkCommandBuffer?]

    // Synchronization
    let imageAvailableSemaphore: VkSemaphore
    let renderFinishedSemaphore: VkSemaphore
    let inFlightFence: VkFence

    // Vertex buffer
    private var vertexBuffer: VulkanBuffer?
    private var vertexCount: UInt32 = 0

    // Allocation callbacks
    private let allocationCallbacks: UnsafePointer<VkAllocationCallbacks>? = nil

    // SDL window reference for resize
    let window: OpaquePointer

    init(window: OpaquePointer) {
        self.window = window

        // Use the static factory to create all Vulkan objects
        // This avoids self-capture issues in Swift 6's strict concurrency
        let created = VulkanRenderer.createVulkanObjects(window: window)

        self.instance = created.instance
        self.surface = created.surface
        self.physicalDevice = created.physicalDevice
        self.device = created.device
        self.queue = created.queue
        self.queueFamilyIndex = created.queueFamilyIndex
        self.swapchain = created.swapchain
        self.swapchainImages = created.swapchainImages
        self.swapchainFormat = created.swapchainFormat
        self.swapchainExtent = created.swapchainExtent
        self.commandPool = created.commandPool
        self.commandBuffers = created.commandBuffers
        self.imageAvailableSemaphore = created.imageAvailableSemaphore
        self.renderFinishedSemaphore = created.renderFinishedSemaphore
        self.inFlightFence = created.inFlightFence

        // --- Graphics Pipeline ---
        self.pipeline = VulkanPipeline(
            device: device,
            swapchainFormat: swapchainFormat,
            swapchainExtent: swapchainExtent,
            swapchainImages: swapchainImages
        )

        // --- Text Renderer ---
        self.textRenderer = TextRenderer(
            device: device,
            physicalDevice: physicalDevice,
            queue: queue,
            commandPool: commandPool,
            renderPass: pipeline.renderPass
        )

        // --- Image Renderer ---
        self.imageRenderer = ImageRenderer(
            device: device,
            physicalDevice: physicalDevice,
            queue: queue,
            commandPool: commandPool,
            renderPass: pipeline.renderPass
        )

        print("Vulkan renderer initialized successfully.")
    }

    // MARK: - Static Factory (avoids self-capture in init)

    private struct CreatedObjects {
        let instance: VkInstance
        let surface: VkSurfaceKHR
        let physicalDevice: VkPhysicalDevice
        let device: VkDevice
        let queue: VkQueue
        let queueFamilyIndex: UInt32
        let swapchain: VkSwapchainKHR
        let swapchainImages: [VkImage?]
        let swapchainFormat: VkFormat
        let swapchainExtent: VkExtent2D
        let commandPool: VkCommandPool
        let commandBuffers: [VkCommandBuffer?]
        let imageAvailableSemaphore: VkSemaphore
        let renderFinishedSemaphore: VkSemaphore
        let inFlightFence: VkFence
    }

    private static func createVulkanObjects(window: OpaquePointer) -> CreatedObjects {
        let allocationCallbacks: UnsafePointer<VkAllocationCallbacks>? = nil

        // --- Instance ---
        var extensionCount: UInt32 = 0
        guard let extensionNamesPointer = SDL_Vulkan_GetInstanceExtensions(&extensionCount) else {
            fail("SDL_Vulkan_GetInstanceExtensions failed: \(currentSDLError())")
        }

        var extensionNames = [UnsafePointer<CChar>?]()
        extensionNames.reserveCapacity(Int(extensionCount))
        for index in 0..<Int(extensionCount) {
            extensionNames.append(extensionNamesPointer[index])
        }

        // MoltenVK on macOS requires the portability enumeration extension
        #if os(macOS)
        let portabilityExtName = SDL_strdup("VK_KHR_portability_enumeration")!
        extensionNames.append(UnsafePointer(portabilityExtName))
        #endif

        var instanceFlags: VkInstanceCreateFlags = 0
        #if os(macOS)
        instanceFlags = vkInstanceCreateEnumeratePortabilityBitKHR
        #endif

        let finalExtensionCount = UInt32(extensionNames.count)

        var instanceHandle: VkInstance?
        extensionNames.withUnsafeBufferPointer { extensionBuffer in
            "Raven Vulkan Bootstrap".withCString { applicationName in
                "Raven".withCString { engineName in
                    var appInfo = VkApplicationInfo(
                        sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
                        pNext: nil,
                        pApplicationName: applicationName,
                        applicationVersion: 1,
                        pEngineName: engineName,
                        engineVersion: 1,
                        apiVersion: vkApiVersion1_0
                    )

                    withUnsafePointer(to: &appInfo) { appInfoPointer in
                        var instanceCreateInfo = VkInstanceCreateInfo(
                            sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                            pNext: nil,
                            flags: instanceFlags,
                            pApplicationInfo: appInfoPointer,
                            enabledLayerCount: 0,
                            ppEnabledLayerNames: nil,
                            enabledExtensionCount: finalExtensionCount,
                            ppEnabledExtensionNames: extensionBuffer.baseAddress
                        )
                        vkCheck(
                            vkCreateInstance(&instanceCreateInfo, nil, &instanceHandle),
                            "vkCreateInstance"
                        )
                    }
                }
            }
        }

        guard let instance = instanceHandle else { fail("vkCreateInstance returned null") }

        // --- Surface ---
        var surfaceHandle: VkSurfaceKHR?
        guard SDL_Vulkan_CreateSurface(window, instance, allocationCallbacks, &surfaceHandle) else {
            fail("SDL_Vulkan_CreateSurface failed: \(currentSDLError())")
        }
        guard let surface = surfaceHandle else { fail("SDL_Vulkan_CreateSurface returned null") }

        // --- Physical Device ---
        var physicalDeviceCount: UInt32 = 0
        vkCheck(
            vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, nil),
            "vkEnumeratePhysicalDevices(count)"
        )
        if physicalDeviceCount == 0 { fail("No Vulkan physical devices found") }

        var physicalDevices = [VkPhysicalDevice?](repeating: nil, count: Int(physicalDeviceCount))
        _ = physicalDevices.withUnsafeMutableBufferPointer { buffer in
            vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, buffer.baseAddress)
        }

        var chosenDevice: VkPhysicalDevice?
        var chosenQueueFamily: UInt32?

        for candidate in physicalDevices {
            if let familyIndex = findGraphicsPresentQueueFamily(candidate, surface) {
                chosenDevice = candidate
                chosenQueueFamily = familyIndex
                break
            }
        }

        guard let physicalDevice = chosenDevice, let queueFamilyIndex = chosenQueueFamily else {
            fail("No Vulkan device with graphics+present queue family found")
        }

        // --- Logical Device ---
        var deviceHandle: VkDevice?
        var queueHandle: VkQueue?
        var queuePriority: Float = 1.0

        // Device extensions: swapchain is always required, portability subset for MoltenVK
        var deviceExtNames: [UnsafeMutablePointer<CChar>] = [SDL_strdup("VK_KHR_swapchain")!]
        #if os(macOS)
        deviceExtNames.append(SDL_strdup("VK_KHR_portability_subset")!)
        #endif
        let deviceExtPtrs: [UnsafePointer<CChar>?] = deviceExtNames.map { UnsafePointer($0) }

        do {
            var queueCreateInfo = VkDeviceQueueCreateInfo(
                sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                queueFamilyIndex: queueFamilyIndex,
                queueCount: 1,
                pQueuePriorities: nil
            )

            var deviceFeatures = VkPhysicalDeviceFeatures()

            withUnsafePointer(to: &queuePriority) { queuePriorityPointer in
                queueCreateInfo.pQueuePriorities = queuePriorityPointer

                withUnsafePointer(to: &queueCreateInfo) { queueCreateInfoPointer in
                    withUnsafePointer(to: &deviceFeatures) { deviceFeaturesPointer in
                        deviceExtPtrs.withUnsafeBufferPointer { extensionBuffer in
                            var deviceCreateInfo = VkDeviceCreateInfo(
                                sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                                pNext: nil,
                                flags: 0,
                                queueCreateInfoCount: 1,
                                pQueueCreateInfos: queueCreateInfoPointer,
                                enabledLayerCount: 0,
                                ppEnabledLayerNames: nil,
                                enabledExtensionCount: UInt32(deviceExtPtrs.count),
                                ppEnabledExtensionNames: extensionBuffer.baseAddress,
                                pEnabledFeatures: deviceFeaturesPointer
                            )
                            vkCheck(
                                vkCreateDevice(
                                    physicalDevice, &deviceCreateInfo, nil, &deviceHandle),
                                "vkCreateDevice"
                            )
                        }
                    }
                }
            }
        }
        deviceExtNames.forEach { SDL_free($0) }

        guard let device = deviceHandle else { fail("vkCreateDevice returned null") }

        vkGetDeviceQueue(device, queueFamilyIndex, 0, &queueHandle)
        guard let queue = queueHandle else { fail("Failed to get device queue") }

        // --- Swapchain ---
        var surfaceCapabilities = VkSurfaceCapabilitiesKHR()
        vkCheck(
            vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &surfaceCapabilities),
            "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"
        )

        var surfaceFormatCount: UInt32 = 0
        vkCheck(
            vkGetPhysicalDeviceSurfaceFormatsKHR(
                physicalDevice, surface, &surfaceFormatCount, nil),
            "vkGetPhysicalDeviceSurfaceFormatsKHR(count)"
        )

        var surfaceFormats = [VkSurfaceFormatKHR](
            repeating: VkSurfaceFormatKHR(), count: Int(surfaceFormatCount))
        _ = surfaceFormats.withUnsafeMutableBufferPointer { buffer in
            vkGetPhysicalDeviceSurfaceFormatsKHR(
                physicalDevice, surface, &surfaceFormatCount, buffer.baseAddress)
        }

        let preferredSurfaceFormat =
            surfaceFormats.first {
                $0.format == VK_FORMAT_B8G8R8A8_UNORM
                    && $0.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
            } ?? surfaceFormats[0]

        let swapchainFormat = preferredSurfaceFormat.format

        var presentModeCount: UInt32 = 0
        vkCheck(
            vkGetPhysicalDeviceSurfacePresentModesKHR(
                physicalDevice, surface, &presentModeCount, nil),
            "vkGetPhysicalDeviceSurfacePresentModesKHR(count)"
        )
        var presentModes = [VkPresentModeKHR](
            repeating: VK_PRESENT_MODE_FIFO_KHR, count: Int(presentModeCount))
        _ = presentModes.withUnsafeMutableBufferPointer { buffer in
            vkGetPhysicalDeviceSurfacePresentModesKHR(
                physicalDevice, surface, &presentModeCount, buffer.baseAddress)
        }

        let presentMode =
            presentModes.contains(VK_PRESENT_MODE_FIFO_KHR)
            ? VK_PRESENT_MODE_FIFO_KHR : presentModes[0]

        var swapchainExtent = surfaceCapabilities.currentExtent
        if swapchainExtent.width == UInt32.max {
            swapchainExtent = VkExtent2D(width: 960, height: 640)
        }

        var desiredImageCount = surfaceCapabilities.minImageCount + 1
        if surfaceCapabilities.maxImageCount > 0
            && desiredImageCount > surfaceCapabilities.maxImageCount
        {
            desiredImageCount = surfaceCapabilities.maxImageCount
        }

        let swapchainUsage: VkImageUsageFlags =
            vkImageUsageColorAttachmentBit | vkImageUsageTransferDstBit
        var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext: nil,
            flags: 0,
            surface: surface,
            minImageCount: desiredImageCount,
            imageFormat: preferredSurfaceFormat.format,
            imageColorSpace: preferredSurfaceFormat.colorSpace,
            imageExtent: swapchainExtent,
            imageArrayLayers: 1,
            imageUsage: swapchainUsage,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            preTransform: surfaceCapabilities.currentTransform,
            compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            presentMode: presentMode,
            clipped: vkTrueValue,
            oldSwapchain: nil
        )

        var swapchainHandle: VkSwapchainKHR?
        vkCheck(
            vkCreateSwapchainKHR(device, &swapchainCreateInfo, nil, &swapchainHandle),
            "vkCreateSwapchainKHR"
        )

        guard let swapchain = swapchainHandle else { fail("vkCreateSwapchainKHR returned null") }

        var swapchainImageCount: UInt32 = 0
        vkCheck(
            vkGetSwapchainImagesKHR(device, swapchain, &swapchainImageCount, nil),
            "vkGetSwapchainImagesKHR(count)"
        )
        var swapchainImages = [VkImage?](repeating: nil, count: Int(swapchainImageCount))
        _ = swapchainImages.withUnsafeMutableBufferPointer { buffer in
            vkGetSwapchainImagesKHR(
                device, swapchain, &swapchainImageCount, buffer.baseAddress)
        }

        // --- Command Pool ---
        var commandPoolHandle: VkCommandPool?
        var commandPoolCreateInfo = VkCommandPoolCreateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            pNext: nil,
            flags: vkCommandPoolResetCommandBufferBit,
            queueFamilyIndex: queueFamilyIndex
        )
        vkCheck(
            vkCreateCommandPool(device, &commandPoolCreateInfo, nil, &commandPoolHandle),
            "vkCreateCommandPool"
        )
        guard let commandPool = commandPoolHandle else {
            fail("vkCreateCommandPool returned null")
        }

        // --- Command Buffers ---
        var commandBuffers = [VkCommandBuffer?](repeating: nil, count: swapchainImages.count)
        var commandBufferAllocateInfo = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: UInt32(commandBuffers.count)
        )
        _ = commandBuffers.withUnsafeMutableBufferPointer { buffer in
            vkAllocateCommandBuffers(device, &commandBufferAllocateInfo, buffer.baseAddress)
        }

        // --- Sync Objects ---
        var semaphoreCreateInfo = VkSemaphoreCreateInfo(
            sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            pNext: nil,
            flags: 0
        )

        var iaSemaphore: VkSemaphore?
        var rfSemaphore: VkSemaphore?
        vkCheck(
            vkCreateSemaphore(device, &semaphoreCreateInfo, nil, &iaSemaphore),
            "vkCreateSemaphore(imageAvailable)"
        )
        vkCheck(
            vkCreateSemaphore(device, &semaphoreCreateInfo, nil, &rfSemaphore),
            "vkCreateSemaphore(renderFinished)"
        )
        guard let imageAvailableSemaphore = iaSemaphore,
            let renderFinishedSemaphore = rfSemaphore
        else {
            fail("Failed to create semaphores")
        }

        var fenceCreateInfo = VkFenceCreateInfo(
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext: nil,
            flags: vkFenceCreateSignaledBit
        )
        var fenceHandle: VkFence?
        vkCheck(vkCreateFence(device, &fenceCreateInfo, nil, &fenceHandle), "vkCreateFence")
        guard let inFlightFence = fenceHandle else { fail("Failed to create fence") }

        return CreatedObjects(
            instance: instance,
            surface: surface,
            physicalDevice: physicalDevice,
            device: device,
            queue: queue,
            queueFamilyIndex: queueFamilyIndex,
            swapchain: swapchain,
            swapchainImages: swapchainImages,
            swapchainFormat: swapchainFormat,
            swapchainExtent: swapchainExtent,
            commandPool: commandPool,
            commandBuffers: commandBuffers,
            imageAvailableSemaphore: imageAvailableSemaphore,
            renderFinishedSemaphore: renderFinishedSemaphore,
            inFlightFence: inFlightFence
        )
    }

    // MARK: - Draw Frame

    private var pendingTextCommands: [TextDrawCommand] = []
    private var pendingImageCommands: [ImageDrawCommand] = []

    func drawFrame(quads: [Quad], textCommands: [TextDrawCommand] = [],
                   imageCommands: [ImageDrawCommand] = [], dirtyRect: VkRect2D? = nil) {
        // Upload vertex data
        let allVertices = quads.flatMap { $0.vertices() }
        let vertexDataSize = VkDeviceSize(MemoryLayout<QuadVertex>.stride * allVertices.count)

        self.pendingTextCommands = textCommands
        self.pendingImageCommands = imageCommands

        if allVertices.isEmpty && textCommands.isEmpty && imageCommands.isEmpty { return }

        // Recreate buffer if needed
        if vertexBuffer == nil || vertexBuffer!.size < vertexDataSize {
            vertexBuffer?.destroy(device: device)
            let vkBufferUsageVertexBit: VkBufferUsageFlags = 0x00000080
            let vkMemoryPropertyHostVisibleBit: VkMemoryPropertyFlags = 0x00000002
            let vkMemoryPropertyHostCoherentBit: VkMemoryPropertyFlags = 0x00000004
            vertexBuffer = VulkanBuffer.create(
                device: device,
                physicalDevice: physicalDevice,
                size: vertexDataSize,
                usage: vkBufferUsageVertexBit,
                memoryPropertyFlags: vkMemoryPropertyHostVisibleBit
                    | vkMemoryPropertyHostCoherentBit
            )
        }

        vertexBuffer!.upload(device: device, data: allVertices)
        vertexCount = UInt32(allVertices.count)

        // Wait for previous frame
        var fenceHandle: VkFence? = inFlightFence
        withUnsafePointer(to: &fenceHandle) { fencePtr in
            vkCheck(
                vkWaitForFences(device, 1, fencePtr, vkTrueValue, UInt64.max),
                "vkWaitForFences"
            )
            vkCheck(vkResetFences(device, 1, fencePtr), "vkResetFences")
        }

        // Acquire next image
        var imageIndex: UInt32 = 0
        let acquireResult = vkAcquireNextImageKHR(
            device, swapchain, UInt64.max, imageAvailableSemaphore, nil, &imageIndex
        )
        if acquireResult == VK_ERROR_OUT_OF_DATE_KHR {
            return
        }
        if acquireResult != VK_SUCCESS && acquireResult != VK_SUBOPTIMAL_KHR {
            fail("vkAcquireNextImageKHR failed with \(acquireResult.rawValue)")
        }

        guard let commandBuffer = commandBuffers[Int(imageIndex)] else {
            fail("Missing command buffer for index \(imageIndex)")
        }

        vkCheck(vkResetCommandBuffer(commandBuffer, 0), "vkResetCommandBuffer")

        // Record commands
        recordCommandBuffer(commandBuffer: commandBuffer, imageIndex: imageIndex, dirtyRect: dirtyRect)

        // Submit
        var waitSemaphoreHandle: VkSemaphore? = imageAvailableSemaphore
        var signalSemaphoreHandle: VkSemaphore? = renderFinishedSemaphore
        var waitStage = vkPipelineStageColorAttachmentOutputBit
        var commandBufferHandle: VkCommandBuffer? = commandBuffer

        withUnsafePointer(to: &waitSemaphoreHandle) { waitSemPtr in
            withUnsafePointer(to: &signalSemaphoreHandle) { signalSemPtr in
                withUnsafePointer(to: &waitStage) { waitStagePtr in
                    withUnsafePointer(to: &commandBufferHandle) { cmdBufPtr in
                        var submitInfo = VkSubmitInfo(
                            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
                            pNext: nil,
                            waitSemaphoreCount: 1,
                            pWaitSemaphores: waitSemPtr,
                            pWaitDstStageMask: waitStagePtr,
                            commandBufferCount: 1,
                            pCommandBuffers: cmdBufPtr,
                            signalSemaphoreCount: 1,
                            pSignalSemaphores: signalSemPtr
                        )
                        vkCheck(
                            vkQueueSubmit(queue, 1, &submitInfo, inFlightFence),
                            "vkQueueSubmit"
                        )
                    }
                }
            }
        }

        // Present
        var presentWaitSemaphore: VkSemaphore? = renderFinishedSemaphore
        var swapchainHandle: VkSwapchainKHR? = swapchain
        var presentImageIndex = imageIndex

        withUnsafePointer(to: &presentWaitSemaphore) { waitSemPtr in
            withUnsafePointer(to: &swapchainHandle) { swapchainPtr in
                withUnsafePointer(to: &presentImageIndex) { imageIndexPtr in
                    var presentInfo = VkPresentInfoKHR(
                        sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
                        pNext: nil,
                        waitSemaphoreCount: 1,
                        pWaitSemaphores: waitSemPtr,
                        swapchainCount: 1,
                        pSwapchains: swapchainPtr,
                        pImageIndices: imageIndexPtr,
                        pResults: nil
                    )
                    let presentResult = vkQueuePresentKHR(queue, &presentInfo)
                    if presentResult != VK_SUCCESS
                        && presentResult != VK_ERROR_OUT_OF_DATE_KHR
                        && presentResult != VK_SUBOPTIMAL_KHR
                    {
                        fail("vkQueuePresentKHR failed with \(presentResult.rawValue)")
                    }
                }
            }
        }
    }

    // MARK: - Command Recording

    private func recordCommandBuffer(commandBuffer: VkCommandBuffer, imageIndex: UInt32, dirtyRect: VkRect2D? = nil) {
        var beginInfo = VkCommandBufferBeginInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext: nil,
            flags: vkCommandBufferOneTimeSubmitBit,
            pInheritanceInfo: nil
        )
        vkCheck(vkBeginCommandBuffer(commandBuffer, &beginInfo), "vkBeginCommandBuffer")

        // Begin render pass
        var clearColor = VkClearValue()
        clearColor.color.float32 = (0.08, 0.12, 0.18, 1.0)

        guard let framebuffer = pipeline.framebuffers[Int(imageIndex)] else {
            fail("Missing framebuffer for index \(imageIndex)")
        }

        withUnsafePointer(to: &clearColor) { clearPtr in
            var renderPassBegin = VkRenderPassBeginInfo(
                sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                pNext: nil,
                renderPass: pipeline.renderPass,
                framebuffer: framebuffer,
                renderArea: VkRect2D(
                    offset: VkOffset2D(x: 0, y: 0),
                    extent: swapchainExtent
                ),
                clearValueCount: 1,
                pClearValues: clearPtr
            )

            vkCmdBeginRenderPass(commandBuffer, &renderPassBegin, VK_SUBPASS_CONTENTS_INLINE)
        }

        // Bind pipeline
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.graphicsPipeline)

        // Set dynamic viewport
        var viewport = VkViewport(
            x: 0,
            y: 0,
            width: Float(swapchainExtent.width),
            height: Float(swapchainExtent.height),
            minDepth: 0.0,
            maxDepth: 1.0
        )
        vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

        // Set dynamic scissor (Dirty Rect / Scissor damage optimization)
        var scissor: VkRect2D
        if let dr = dirtyRect {
            scissor = dr
        } else {
            scissor = VkRect2D(
                offset: VkOffset2D(x: 0, y: 0),
                extent: swapchainExtent
            )
        }
        vkCmdSetScissor(commandBuffer, 0, 1, &scissor)

        // Push constants (viewport size)
        var viewportSize: (Float, Float) = (
            Float(swapchainExtent.width), Float(swapchainExtent.height)
        )
        withUnsafePointer(to: &viewportSize) { ptr in
            vkCmdPushConstants(
                commandBuffer,
                pipeline.pipelineLayout,
                vkShaderStageVertexBit,
                0,
                UInt32(MemoryLayout<Float>.size * 2),
                ptr
            )
        }

        // Bind vertex buffer and draw quads
        if let vb = vertexBuffer?.buffer, vertexCount > 0 {
            var vertexBufferHandle: VkBuffer? = vb
            var offset: VkDeviceSize = 0
            withUnsafePointer(to: &vertexBufferHandle) { bufferPtr in
                vkCmdBindVertexBuffers(commandBuffer, 0, 1, bufferPtr, &offset)
            }
            vkCmdDraw(commandBuffer, vertexCount, 1, 0, 0)
        }

        // Draw images (between quads and text so images appear under text)
        if !pendingImageCommands.isEmpty {
            let vps = (Float(swapchainExtent.width), Float(swapchainExtent.height))
            imageRenderer.recordDraw(
                commandBuffer: commandBuffer,
                commands: pendingImageCommands,
                viewportSize: vps
            )
        }

        // Draw text (within the same render pass, after images so text is on top)
        if !pendingTextCommands.isEmpty {
            let vps = (Float(swapchainExtent.width), Float(swapchainExtent.height))
            textRenderer.recordDraw(
                commandBuffer: commandBuffer,
                commands: pendingTextCommands,
                viewportSize: vps
            )
        }

        vkCmdEndRenderPass(commandBuffer)
        vkCheck(vkEndCommandBuffer(commandBuffer), "vkEndCommandBuffer")
    }

    // MARK: - Cleanup

    func destroy() {
        vkCheck(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")

        vertexBuffer?.destroy(device: device)
        imageRenderer.destroy()
        textRenderer.destroy()
        pipeline.destroy()

        vkDestroyFence(device, inFlightFence, nil)
        vkDestroySemaphore(device, renderFinishedSemaphore, nil)
        vkDestroySemaphore(device, imageAvailableSemaphore, nil)
        vkDestroyCommandPool(device, commandPool, nil)
        vkDestroySwapchainKHR(device, swapchain, nil)
        vkDestroyDevice(device, nil)
        SDL_Vulkan_DestroySurface(instance, surface, allocationCallbacks)
        vkDestroyInstance(instance, nil)
    }
}
