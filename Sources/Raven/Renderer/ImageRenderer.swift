import CSTBImage
import CVulkan

// MARK: - ImageDrawCommand

/// A draw command for rendering a loaded image texture.
public struct ImageDrawCommand {
    public let textureId: String   // Unique key (file path)
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float
    public var opacity: Float

    public init(textureId: String, x: Float, y: Float,
                width: Float, height: Float, opacity: Float = 1.0) {
        self.textureId = textureId
        self.x = x; self.y = y
        self.width = width; self.height = height
        self.opacity = opacity
    }
}

// MARK: - LoadedTexture

/// A Vulkan-backed texture loaded from an image file.
struct LoadedTexture {
    var image: VkImage?
    var memory: VkDeviceMemory?
    var imageView: VkImageView?
    var descriptorSet: VkDescriptorSet?
    var width: Int
    var height: Int
}

// MARK: - ImageRenderer

/// Manages loading image files into Vulkan textures and rendering them.
/// Each image gets its own descriptor set, all sharing a common sampler
/// and graphics pipeline (reuses the text shader pipeline format).
public class ImageRenderer {
    private let device: VkDevice
    private let physicalDevice: VkPhysicalDevice
    private let queue: VkQueue
    private let commandPool: VkCommandPool

    // Shared resources
    private var sampler: VkSampler?
    private var descriptorPool: VkDescriptorPool?
    private var descriptorSetLayout: VkDescriptorSetLayout?
    private var pipelineLayout: VkPipelineLayout?
    private var graphicsPipeline: VkPipeline?

    // Texture cache: path → LoadedTexture
    private var textureCache: [String: LoadedTexture] = [:]
    private var maxDescriptorSets: UInt32 = 64

    // Vertex buffer (reused each frame)
    private var vertexBuffer: VulkanBuffer?
    private var vertexCount: UInt32 = 0

    public init(device: VkDevice, physicalDevice: VkPhysicalDevice,
                queue: VkQueue, commandPool: VkCommandPool,
                renderPass: VkRenderPass) {
        self.device = device
        self.physicalDevice = physicalDevice
        self.queue = queue
        self.commandPool = commandPool

        createSampler()
        createDescriptorResources()
        createImagePipeline(renderPass: renderPass)
    }

    // MARK: - Texture Loading

    /// Load an image file and create a Vulkan texture.
    /// Returns the natural (width, height) of the image, or nil if loading fails.
    @discardableResult
    public func loadImage(path: String) -> (Int, Int)? {
        if let existing = textureCache[path] {
            return (existing.width, existing.height)
        }

        // Load with stb_image
        var w: Int32 = 0, h: Int32 = 0, channels: Int32 = 0
        guard let pixels = stbi_load(path, &w, &h, &channels, 4) else {
            print("ImageRenderer: Failed to load \(path)")
            return nil
        }
        defer { stbi_image_free(pixels) }

        let width = Int(w), height = Int(h)
        let imageSize = VkDeviceSize(width * height * 4)

        // Create staging buffer
        let vkBufferUsageTransferSrc: VkBufferUsageFlags = 0x00000001
        let vkMemHostVisible: VkMemoryPropertyFlags = 0x00000002
        let vkMemHostCoherent: VkMemoryPropertyFlags = 0x00000004
        let staging = VulkanBuffer.create(
            device: device, physicalDevice: physicalDevice,
            size: imageSize, usage: vkBufferUsageTransferSrc,
            memoryPropertyFlags: vkMemHostVisible | vkMemHostCoherent
        )

        // Upload pixel data
        var mappedPtr: UnsafeMutableRawPointer?
        vkMapMemory(device, staging.memory, 0, imageSize, 0, &mappedPtr)
        mappedPtr?.copyMemory(from: pixels, byteCount: Int(imageSize))
        vkUnmapMemory(device, staging.memory)

        // Create VkImage (RGBA8)
        let vkImageUsageSampled: VkImageUsageFlags = 0x00000004
        let vkImageUsageTransferDst: VkImageUsageFlags = 0x00000002
        var imageCI = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil, flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: VK_FORMAT_R8G8B8A8_UNORM,
            extent: VkExtent3D(width: UInt32(w), height: UInt32(h), depth: 1),
            mipLevels: 1, arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: vkImageUsageSampled | vkImageUsageTransferDst,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0, pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )
        var texImage: VkImage?
        vkCheck(vkCreateImage(device, &imageCI, nil, &texImage), "vkCreateImage(image)")

        // Allocate memory
        var memReq = VkMemoryRequirements()
        vkGetImageMemoryRequirements(device, texImage, &memReq)
        let vkMemDeviceLocal: VkMemoryPropertyFlags = 0x00000001
        let memTypeIdx = findMemoryType(
            physicalDevice: physicalDevice,
            typeFilter: memReq.memoryTypeBits,
            properties: vkMemDeviceLocal
        )
        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memReq.size,
            memoryTypeIndex: memTypeIdx
        )
        var texMemory: VkDeviceMemory?
        vkCheck(vkAllocateMemory(device, &allocInfo, nil, &texMemory), "vkAllocateMemory(image)")
        vkCheck(vkBindImageMemory(device, texImage, texMemory, 0), "vkBindImageMemory(image)")

        // Transfer
        let cmdBuf = beginSingleTimeCommands()

        transitionImageLayout(cmdBuf: cmdBuf, image: texImage!,
                              oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                              newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)

        var region = VkBufferImageCopy(
            bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
            imageSubresource: VkImageSubresourceLayers(
                aspectMask: vkImageAspectColorBit,
                mipLevel: 0, baseArrayLayer: 0, layerCount: 1
            ),
            imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
            imageExtent: VkExtent3D(width: UInt32(w), height: UInt32(h), depth: 1)
        )
        vkCmdCopyBufferToImage(cmdBuf, staging.buffer, texImage,
                               VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region)

        transitionImageLayout(cmdBuf: cmdBuf, image: texImage!,
                              oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                              newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

        endSingleTimeCommands(cmdBuf)
        staging.destroy(device: device)

        // Image view
        var viewCI = VkImageViewCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext: nil, flags: 0,
            image: texImage,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: VK_FORMAT_R8G8B8A8_UNORM,
            components: VkComponentMapping(
                r: VK_COMPONENT_SWIZZLE_IDENTITY,
                g: VK_COMPONENT_SWIZZLE_IDENTITY,
                b: VK_COMPONENT_SWIZZLE_IDENTITY,
                a: VK_COMPONENT_SWIZZLE_IDENTITY
            ),
            subresourceRange: VkImageSubresourceRange(
                aspectMask: vkImageAspectColorBit,
                baseMipLevel: 0, levelCount: 1,
                baseArrayLayer: 0, layerCount: 1
            )
        )
        var texImageView: VkImageView?
        vkCheck(vkCreateImageView(device, &viewCI, nil, &texImageView), "vkCreateImageView(image)")

        // Allocate descriptor set
        var dsAllocInfo = VkDescriptorSetAllocateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            pNext: nil,
            descriptorPool: descriptorPool,
            descriptorSetCount: 1,
            pSetLayouts: &descriptorSetLayout
        )
        var ds: VkDescriptorSet?
        vkCheck(vkAllocateDescriptorSets(device, &dsAllocInfo, &ds), "vkAllocateDescriptorSets(image)")

        // Write descriptor
        let vkDescTypeSampler = VkDescriptorType(rawValue: 1)
        var imgInfo = VkDescriptorImageInfo(
            sampler: sampler,
            imageView: texImageView,
            imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        )
        var writeDS = VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            pNext: nil,
            dstSet: ds,
            dstBinding: 0, dstArrayElement: 0,
            descriptorCount: 1,
            descriptorType: vkDescTypeSampler,
            pImageInfo: &imgInfo,
            pBufferInfo: nil,
            pTexelBufferView: nil
        )
        vkUpdateDescriptorSets(device, 1, &writeDS, 0, nil)

        // Cache
        textureCache[path] = LoadedTexture(
            image: texImage, memory: texMemory,
            imageView: texImageView, descriptorSet: ds,
            width: width, height: height
        )

        print("ImageRenderer: Loaded \(path) (\(width)×\(height))")
        return (width, height)
    }

    /// Get loaded texture dimensions.
    public func textureSize(for path: String) -> (Int, Int)? {
        textureCache[path].map { ($0.width, $0.height) }
    }

    // MARK: - Draw

    /// Record image draw commands into the current render pass.
    public func recordDraw(commandBuffer: VkCommandBuffer,
                           commands: [ImageDrawCommand],
                           viewportSize: (Float, Float)) {
        if commands.isEmpty { return }

        // Generate vertices (same TextVertex format: pos + uv + color)
        var vertices: [TextVertex] = []

        for cmd in commands {
            guard textureCache[cmd.textureId] != nil else { continue }

            let x0 = cmd.x, y0 = cmd.y
            let x1 = cmd.x + cmd.width, y1 = cmd.y + cmd.height
            let a = cmd.opacity

            // Two triangles, white color (tinted by opacity), full UV
            vertices.append(TextVertex(x0, y0, 0, 0, 1, 1, 1, a))
            vertices.append(TextVertex(x0, y1, 0, 1, 1, 1, 1, a))
            vertices.append(TextVertex(x1, y1, 1, 1, 1, 1, 1, a))

            vertices.append(TextVertex(x0, y0, 0, 0, 1, 1, 1, a))
            vertices.append(TextVertex(x1, y1, 1, 1, 1, 1, 1, a))
            vertices.append(TextVertex(x1, y0, 1, 0, 1, 1, 1, a))
        }

        if vertices.isEmpty { return }

        // Upload vertex buffer
        let dataSize = VkDeviceSize(MemoryLayout<TextVertex>.stride * vertices.count)
        if vertexBuffer == nil || vertexBuffer!.size < dataSize {
            vertexBuffer?.destroy(device: device)
            let vkBufferUsageVertexBit: VkBufferUsageFlags = 0x00000080
            let vkMemHostVisible: VkMemoryPropertyFlags = 0x00000002
            let vkMemHostCoherent: VkMemoryPropertyFlags = 0x00000004
            vertexBuffer = VulkanBuffer.create(
                device: device, physicalDevice: physicalDevice,
                size: dataSize, usage: vkBufferUsageVertexBit,
                memoryPropertyFlags: vkMemHostVisible | vkMemHostCoherent
            )
        }
        vertexBuffer!.upload(device: device, data: vertices)

        // Bind pipeline
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)

        // Push constants (viewport size)
        var vps = viewportSize
        withUnsafePointer(to: &vps) { ptr in
            vkCmdPushConstants(commandBuffer, pipelineLayout, vkShaderStageVertexBit,
                               0, UInt32(MemoryLayout<Float>.size * 2), ptr)
        }

        // Bind vertex buffer
        if let vb = vertexBuffer?.buffer {
            var bufHandle: VkBuffer? = vb
            var offset: VkDeviceSize = 0
            withUnsafePointer(to: &bufHandle) { bufPtr in
                vkCmdBindVertexBuffers(commandBuffer, 0, 1, bufPtr, &offset)
            }
        }

        // Draw each image with its own descriptor set (6 verts each)
        var vertexOffset: UInt32 = 0
        for cmd in commands {
            guard let tex = textureCache[cmd.textureId] else { continue }
            var dsHandle: VkDescriptorSet? = tex.descriptorSet
            withUnsafePointer(to: &dsHandle) { dsPtr in
                vkCmdBindDescriptorSets(
                    commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
                    pipelineLayout, 0, 1, dsPtr, 0, nil
                )
            }
            vkCmdDraw(commandBuffer, 6, 1, vertexOffset, 0)
            vertexOffset += 6
        }
    }

    // MARK: - Setup

    private func createSampler() {
        var samplerCI = VkSamplerCreateInfo(
            sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            pNext: nil, flags: 0,
            magFilter: VK_FILTER_LINEAR,
            minFilter: VK_FILTER_LINEAR,
            mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
            addressModeU: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            addressModeV: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            addressModeW: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            mipLodBias: 0, anisotropyEnable: 0, maxAnisotropy: 1,
            compareEnable: 0, compareOp: VK_COMPARE_OP_ALWAYS,
            minLod: 0, maxLod: 0,
            borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            unnormalizedCoordinates: 0
        )
        vkCheck(vkCreateSampler(device, &samplerCI, nil, &sampler), "vkCreateSampler(image)")
    }

    private func createDescriptorResources() {
        let vkDescTypeSampler = VkDescriptorType(rawValue: 1)

        var layoutBinding = VkDescriptorSetLayoutBinding(
            binding: 0,
            descriptorType: vkDescTypeSampler,
            descriptorCount: 1,
            stageFlags: vkShaderStageFragmentBit,
            pImmutableSamplers: nil
        )
        var layoutCI = VkDescriptorSetLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            pNext: nil, flags: 0,
            bindingCount: 1,
            pBindings: &layoutBinding
        )
        vkCheck(vkCreateDescriptorSetLayout(device, &layoutCI, nil, &descriptorSetLayout),
                "vkCreateDescriptorSetLayout(image)")

        var poolSize = VkDescriptorPoolSize(
            type: vkDescTypeSampler,
            descriptorCount: maxDescriptorSets
        )
        var poolCI = VkDescriptorPoolCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            pNext: nil, flags: 0,
            maxSets: maxDescriptorSets,
            poolSizeCount: 1,
            pPoolSizes: &poolSize
        )
        vkCheck(vkCreateDescriptorPool(device, &poolCI, nil, &descriptorPool),
                "vkCreateDescriptorPool(image)")
    }

    private func createImagePipeline(renderPass: VkRenderPass) {
        // Push constant range (viewport size)
        var pushConstantRange = VkPushConstantRange(
            stageFlags: vkShaderStageVertexBit,
            offset: 0,
            size: UInt32(MemoryLayout<Float>.size * 2)
        )

        var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            pNext: nil, flags: 0,
            setLayoutCount: 1,
            pSetLayouts: &descriptorSetLayout,
            pushConstantRangeCount: 1,
            pPushConstantRanges: &pushConstantRange
        )
        vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, nil, &pipelineLayout),
                "vkCreatePipelineLayout(image)")

        // Reuse text vertex shader, but use image-specific fragment shader (direct RGBA sampling)
        let vertCode = loadSPIRV(named: "text_vert.spv")
        let fragCode = loadSPIRV(named: "image_frag.spv")

        let vertModule = createShaderModule(device: device, code: vertCode)
        let fragModule = createShaderModule(device: device, code: fragCode)
        defer {
            vkDestroyShaderModule(device, vertModule, nil)
            vkDestroyShaderModule(device, fragModule, nil)
        }

        // Use withCString for the entry point name
        "main".withCString { mainPtr in
            var shaderStages: [VkPipelineShaderStageCreateInfo] = [
                VkPipelineShaderStageCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    pNext: nil, flags: 0,
                    stage: VK_SHADER_STAGE_VERTEX_BIT,
                    module: vertModule,
                    pName: mainPtr,
                    pSpecializationInfo: nil
                ),
                VkPipelineShaderStageCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    pNext: nil, flags: 0,
                    stage: VK_SHADER_STAGE_FRAGMENT_BIT,
                    module: fragModule,
                    pName: mainPtr,
                    pSpecializationInfo: nil
                )
            ]

            // Vertex input: same as TextVertex (pos2 + uv2 + color4)
            var bindingDesc = VkVertexInputBindingDescription(
                binding: 0,
                stride: UInt32(MemoryLayout<TextVertex>.stride),
                inputRate: VK_VERTEX_INPUT_RATE_VERTEX
            )

            var attrDescs: [VkVertexInputAttributeDescription] = [
                VkVertexInputAttributeDescription(location: 0, binding: 0,
                    format: VK_FORMAT_R32G32_SFLOAT, offset: 0),
                VkVertexInputAttributeDescription(location: 1, binding: 0,
                    format: VK_FORMAT_R32G32_SFLOAT,
                    offset: UInt32(MemoryLayout<Float>.size * 2)),
                VkVertexInputAttributeDescription(location: 2, binding: 0,
                    format: VK_FORMAT_R32G32B32A32_SFLOAT,
                    offset: UInt32(MemoryLayout<Float>.size * 4))
            ]

            var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                vertexBindingDescriptionCount: 1,
                pVertexBindingDescriptions: &bindingDesc,
                vertexAttributeDescriptionCount: UInt32(attrDescs.count),
                pVertexAttributeDescriptions: &attrDescs[0]
            )

            var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
                primitiveRestartEnable: 0
            )

            var viewportState = VkPipelineViewportStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                viewportCount: 1, pViewports: nil,
                scissorCount: 1, pScissors: nil
            )

            var rasterizer = VkPipelineRasterizationStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                depthClampEnable: 0, rasterizerDiscardEnable: 0,
                polygonMode: VK_POLYGON_MODE_FILL,
                cullMode: 0, frontFace: VK_FRONT_FACE_CLOCKWISE,
                depthBiasEnable: 0, depthBiasConstantFactor: 0,
                depthBiasClamp: 0, depthBiasSlopeFactor: 0,
                lineWidth: 1.0
            )

            var multisample = VkPipelineMultisampleStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
                sampleShadingEnable: 0, minSampleShading: 1,
                pSampleMask: nil, alphaToCoverageEnable: 0, alphaToOneEnable: 0
            )

            // Alpha blending
            let vkBlendSrcAlpha = VkBlendFactor(rawValue: 6)
            let vkBlendOneMinusSrcAlpha = VkBlendFactor(rawValue: 7)
            let vkBlendOne = VkBlendFactor(rawValue: 1)
            let vkBlendZero = VkBlendFactor(rawValue: 0)

            var colorBlendAttach = VkPipelineColorBlendAttachmentState(
                blendEnable: vkTrueValue,
                srcColorBlendFactor: vkBlendSrcAlpha,
                dstColorBlendFactor: vkBlendOneMinusSrcAlpha,
                colorBlendOp: VK_BLEND_OP_ADD,
                srcAlphaBlendFactor: vkBlendOne,
                dstAlphaBlendFactor: vkBlendZero,
                alphaBlendOp: VK_BLEND_OP_ADD,
                colorWriteMask: vkColorComponentAllBits
            )

            var colorBlending = VkPipelineColorBlendStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                logicOpEnable: 0, logicOp: VK_LOGIC_OP_COPY,
                attachmentCount: 1,
                pAttachments: &colorBlendAttach,
                blendConstants: (0, 0, 0, 0)
            )

            var dynamicStates: [VkDynamicState] = [vkDynamicStateViewport, vkDynamicStateScissor]
            var dynamicState = VkPipelineDynamicStateCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                pNext: nil, flags: 0,
                dynamicStateCount: UInt32(dynamicStates.count),
                pDynamicStates: &dynamicStates[0]
            )

            var pipelineInfo = VkGraphicsPipelineCreateInfo(
                sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                pNext: nil, flags: 0,
                stageCount: UInt32(shaderStages.count),
                pStages: &shaderStages[0],
                pVertexInputState: &vertexInputInfo,
                pInputAssemblyState: &inputAssembly,
                pTessellationState: nil,
                pViewportState: &viewportState,
                pRasterizationState: &rasterizer,
                pMultisampleState: &multisample,
                pDepthStencilState: nil,
                pColorBlendState: &colorBlending,
                pDynamicState: &dynamicState,
                layout: pipelineLayout,
                renderPass: renderPass,
                subpass: 0,
                basePipelineHandle: nil,
                basePipelineIndex: -1
            )

            vkCheck(
                vkCreateGraphicsPipelines(device, nil, 1, &pipelineInfo, nil, &graphicsPipeline),
                "vkCreateGraphicsPipelines(image)"
            )
        }
    }

    // MARK: - Helper functions

    private func beginSingleTimeCommands() -> VkCommandBuffer {
        var allocInfo = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1
        )
        var cmdBuf: VkCommandBuffer?
        vkCheck(vkAllocateCommandBuffers(device, &allocInfo, &cmdBuf), "vkAllocateCommandBuffers(img)")

        var beginInfo = VkCommandBufferBeginInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext: nil,
            flags: vkCommandBufferOneTimeSubmitBit,
            pInheritanceInfo: nil
        )
        vkCheck(vkBeginCommandBuffer(cmdBuf, &beginInfo), "vkBeginCommandBuffer(img)")
        return cmdBuf!
    }

    private func endSingleTimeCommands(_ cmdBuf: VkCommandBuffer) {
        vkCheck(vkEndCommandBuffer(cmdBuf), "vkEndCommandBuffer(img)")

        var cmdBufHandle: VkCommandBuffer? = cmdBuf
        var submitInfo = VkSubmitInfo(
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext: nil,
            waitSemaphoreCount: 0, pWaitSemaphores: nil, pWaitDstStageMask: nil,
            commandBufferCount: 1, pCommandBuffers: &cmdBufHandle,
            signalSemaphoreCount: 0, pSignalSemaphores: nil
        )
        vkCheck(vkQueueSubmit(queue, 1, &submitInfo, nil), "vkQueueSubmit(img)")
        vkCheck(vkQueueWaitIdle(queue), "vkQueueWaitIdle(img)")

        var cmdBufToFree: VkCommandBuffer? = cmdBuf
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBufToFree)
    }

    private func transitionImageLayout(cmdBuf: VkCommandBuffer, image: VkImage,
                                       oldLayout: VkImageLayout, newLayout: VkImageLayout) {
        var srcAccess: VkAccessFlags = 0
        var dstAccess: VkAccessFlags = 0
        var srcStage: VkPipelineStageFlags = 0
        var dstStage: VkPipelineStageFlags = 0

        if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
            srcAccess = 0; dstAccess = vkAccessTransferWriteBit
            srcStage = vkPipelineStageTopOfPipeBit; dstStage = vkPipelineStageTransferBit
        } else if oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL {
            srcAccess = vkAccessTransferWriteBit; dstAccess = 0x00000020
            srcStage = vkPipelineStageTransferBit; dstStage = 0x00000080
        }

        var barrier = VkImageMemoryBarrier(
            sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            pNext: nil,
            srcAccessMask: srcAccess, dstAccessMask: dstAccess,
            oldLayout: oldLayout, newLayout: newLayout,
            srcQueueFamilyIndex: vkQueueFamilyIgnored,
            dstQueueFamilyIndex: vkQueueFamilyIgnored,
            image: image,
            subresourceRange: VkImageSubresourceRange(
                aspectMask: vkImageAspectColorBit,
                baseMipLevel: 0, levelCount: 1,
                baseArrayLayer: 0, layerCount: 1
            )
        )
        vkCmdPipelineBarrier(cmdBuf, srcStage, dstStage, 0,
                             0, nil, 0, nil, 1, &barrier)
    }

    // MARK: - Cleanup

    public func destroy() {
        vertexBuffer?.destroy(device: device)

        for (_, tex) in textureCache {
            vkDestroyImageView(device, tex.imageView, nil)
            vkDestroyImage(device, tex.image, nil)
            vkFreeMemory(device, tex.memory, nil)
        }
        textureCache.removeAll()

        vkDestroyPipeline(device, graphicsPipeline, nil)
        vkDestroyPipelineLayout(device, pipelineLayout, nil)
        vkDestroyDescriptorPool(device, descriptorPool, nil)
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        vkDestroySampler(device, sampler, nil)
    }
}

// MARK: - Shader Module Helper (shared with TextRenderer)
private func createShaderModule(device: VkDevice, code: [UInt8]) -> VkShaderModule? {
    code.withUnsafeBytes { rawBuffer in
        let uint32Pointer = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt32.self)
        var createInfo = VkShaderModuleCreateInfo(
            sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            pNext: nil, flags: 0,
            codeSize: rawBuffer.count,
            pCode: uint32Pointer
        )
        var shaderModule: VkShaderModule?
        vkCheck(vkCreateShaderModule(device, &createInfo, nil, &shaderModule),
                "vkCreateShaderModule(image)")
        return shaderModule
    }
}
