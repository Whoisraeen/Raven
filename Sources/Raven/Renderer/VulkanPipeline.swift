import CVulkan

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - VulkanPipeline

/// Holds the Vulkan graphics pipeline, render pass, and associated resources
/// needed to draw colored 2D quads.
final class VulkanPipeline {
    let device: VkDevice
    let renderPass: VkRenderPass
    let pipelineLayout: VkPipelineLayout
    let graphicsPipeline: VkPipeline
    let pipelineCache: VkPipelineCache?
    private(set) var framebuffers: [VkFramebuffer?]
    private(set) var imageViews: [VkImageView?]

    /// Path for persisting the pipeline cache to disk.
    static let cacheFilePath: String = {
        #if os(Windows)
        if let appData = getenv("LOCALAPPDATA") {
            return String(cString: appData) + "\\Raven\\pipeline_cache.bin"
        }
        return ".raven_pipeline_cache.bin"
        #elseif os(macOS)
        if let home = getenv("HOME") {
            return String(cString: home) + "/Library/Caches/Raven/pipeline_cache.bin"
        }
        return ".raven_pipeline_cache.bin"
        #else
        if let home = getenv("HOME") {
            return String(cString: home) + "/.cache/raven/pipeline_cache.bin"
        }
        return ".raven_pipeline_cache.bin"
        #endif
    }()

    init(
        device: VkDevice,
        swapchainFormat: VkFormat,
        swapchainExtent: VkExtent2D,
        swapchainImages: [VkImage?]
    ) {
        self.device = device

        // --- Render Pass ---
        var colorAttachment = VkAttachmentDescription(
            flags: 0,
            format: swapchainFormat,
            samples: VK_SAMPLE_COUNT_1_BIT,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        )

        var colorAttachmentRef = VkAttachmentReference(
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        )

        var subpass = VkSubpassDescription(
            flags: 0,
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount: 0,
            pInputAttachments: nil,
            colorAttachmentCount: 1,
            pColorAttachments: nil,
            pResolveAttachments: nil,
            pDepthStencilAttachment: nil,
            preserveAttachmentCount: 0,
            pPreserveAttachments: nil
        )

        var dependency = VkSubpassDependency(
            srcSubpass: UInt32(VK_SUBPASS_EXTERNAL),
            dstSubpass: 0,
            srcStageMask: vkPipelineStageColorAttachmentOutputBit,
            dstStageMask: vkPipelineStageColorAttachmentOutputBit,
            srcAccessMask: 0,
            dstAccessMask: vkAccessColorAttachmentWriteBit,
            dependencyFlags: 0
        )

        var renderPassHandle: VkRenderPass?
        withUnsafePointer(to: &colorAttachmentRef) { attachmentRefPtr in
            subpass.pColorAttachments = attachmentRefPtr

            withUnsafePointer(to: &colorAttachment) { attachmentPtr in
                withUnsafePointer(to: &subpass) { subpassPtr in
                    withUnsafePointer(to: &dependency) { dependencyPtr in
                        var renderPassInfo = VkRenderPassCreateInfo(
                            sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                            pNext: nil,
                            flags: 0,
                            attachmentCount: 1,
                            pAttachments: attachmentPtr,
                            subpassCount: 1,
                            pSubpasses: subpassPtr,
                            dependencyCount: 1,
                            pDependencies: dependencyPtr
                        )
                        vkCheck(
                            vkCreateRenderPass(device, &renderPassInfo, nil, &renderPassHandle),
                            "vkCreateRenderPass"
                        )
                    }
                }
            }
        }

        guard let renderPass = renderPassHandle else { fail("vkCreateRenderPass returned null") }
        self.renderPass = renderPass

        // --- Pipeline Layout (push constant for viewport size) ---
        var pushConstantRange = VkPushConstantRange(
            stageFlags: vkShaderStageVertexBit,
            offset: 0,
            size: UInt32(MemoryLayout<Float>.size * 2)  // vec2 viewportSize
        )

        var pipelineLayoutHandle: VkPipelineLayout?
        withUnsafePointer(to: &pushConstantRange) { pushConstantPtr in
            var layoutInfo = VkPipelineLayoutCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
                pNext: nil,
                flags: 0,
                setLayoutCount: 0,
                pSetLayouts: nil,
                pushConstantRangeCount: 1,
                pPushConstantRanges: pushConstantPtr
            )
            vkCheck(
                vkCreatePipelineLayout(device, &layoutInfo, nil, &pipelineLayoutHandle),
                "vkCreatePipelineLayout"
            )
        }

        guard let pipelineLayout = pipelineLayoutHandle else {
            fail("vkCreatePipelineLayout returned null")
        }
        self.pipelineLayout = pipelineLayout

        // --- Pipeline Cache (load from disk if available) ---
        var pipelineCacheHandle: VkPipelineCache?
        let cacheData = VulkanPipeline.loadCacheFromDisk()
        if let data = cacheData {
            data.withUnsafeBytes { rawBuffer in
                var cacheCreateInfo = VkPipelineCacheCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    initialDataSize: rawBuffer.count,
                    pInitialData: rawBuffer.baseAddress
                )
                let result = vkCreatePipelineCache(device, &cacheCreateInfo, nil, &pipelineCacheHandle)
                if result != VK_SUCCESS {
                    // Cache data may be stale/incompatible — create empty
                    pipelineCacheHandle = nil
                }
            }
        }
        if pipelineCacheHandle == nil {
            var cacheCreateInfo = VkPipelineCacheCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                initialDataSize: 0,
                pInitialData: nil
            )
            vkCreatePipelineCache(device, &cacheCreateInfo, nil, &pipelineCacheHandle)
        }
        self.pipelineCache = pipelineCacheHandle

        // --- Shader Modules ---
        let vertSPIRV = loadSPIRV(named: "quad_vert.spv")
        let fragSPIRV = loadSPIRV(named: "quad_frag.spv")

        let vertModule = VulkanPipeline.createShaderModule(device: device, spirv: vertSPIRV)
        let fragModule = VulkanPipeline.createShaderModule(device: device, spirv: fragSPIRV)

        defer {
            vkDestroyShaderModule(device, vertModule, nil)
            vkDestroyShaderModule(device, fragModule, nil)
        }

        // --- Shader Stages ---
        let entryName = Array("main".utf8CString)
        let entryNamePointer = UnsafeMutablePointer<CChar>.allocate(capacity: entryName.count)
        entryNamePointer.initialize(from: entryName, count: entryName.count)
        defer { entryNamePointer.deallocate() }

        var stages = [
            VkPipelineShaderStageCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                stage: VK_SHADER_STAGE_VERTEX_BIT,
                module: vertModule,
                pName: entryNamePointer,
                pSpecializationInfo: nil
            ),
            VkPipelineShaderStageCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                stage: VK_SHADER_STAGE_FRAGMENT_BIT,
                module: fragModule,
                pName: entryNamePointer,
                pSpecializationInfo: nil
            ),
        ]

        // --- Vertex Input ---
        // QuadVertex: posX, posY (2 floats) + r, g, b, a (4 floats) = 24 bytes
        var bindingDescription = VkVertexInputBindingDescription(
            binding: 0,
            stride: UInt32(MemoryLayout<QuadVertex>.stride),
            inputRate: VK_VERTEX_INPUT_RATE_VERTEX
        )

        var attributeDescriptions = [
            // location 0: vec2 position
            VkVertexInputAttributeDescription(
                location: 0,
                binding: 0,
                format: VK_FORMAT_R32G32_SFLOAT,
                offset: 0
            ),
            // location 1: vec4 color
            VkVertexInputAttributeDescription(
                location: 1,
                binding: 0,
                format: VK_FORMAT_R32G32B32A32_SFLOAT,
                offset: UInt32(MemoryLayout<Float>.size * 2)
            ),
        ]

        // --- Graphics Pipeline ---
        var pipelineHandle: VkPipeline?

        withUnsafePointer(to: &bindingDescription) { bindingPtr in
            attributeDescriptions.withUnsafeBufferPointer { attrBuffer in
                var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    vertexBindingDescriptionCount: 1,
                    pVertexBindingDescriptions: bindingPtr,
                    vertexAttributeDescriptionCount: UInt32(attrBuffer.count),
                    pVertexAttributeDescriptions: attrBuffer.baseAddress
                )

                var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
                    primitiveRestartEnable: 0
                )

                var viewportState = VkPipelineViewportStateCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    viewportCount: 1,
                    pViewports: nil,
                    scissorCount: 1,
                    pScissors: nil
                )

                var rasterizer = VkPipelineRasterizationStateCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    depthClampEnable: 0,
                    rasterizerDiscardEnable: 0,
                    polygonMode: VK_POLYGON_MODE_FILL,
                    cullMode: 0,  // VK_CULL_MODE_NONE for 2D UI
                    frontFace: VK_FRONT_FACE_CLOCKWISE,
                    depthBiasEnable: 0,
                    depthBiasConstantFactor: 0,
                    depthBiasClamp: 0,
                    depthBiasSlopeFactor: 0,
                    lineWidth: 1.0
                )

                var multisampling = VkPipelineMultisampleStateCreateInfo(
                    sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                    pNext: nil,
                    flags: 0,
                    rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
                    sampleShadingEnable: 0,
                    minSampleShading: 1.0,
                    pSampleMask: nil,
                    alphaToCoverageEnable: 0,
                    alphaToOneEnable: 0
                )

                var colorBlendAttachment = VkPipelineColorBlendAttachmentState(
                    blendEnable: vkTrueValue,
                    srcColorBlendFactor: VK_BLEND_FACTOR_SRC_ALPHA,
                    dstColorBlendFactor: VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
                    colorBlendOp: VK_BLEND_OP_ADD,
                    srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
                    dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
                    alphaBlendOp: VK_BLEND_OP_ADD,
                    colorWriteMask: vkColorComponentAllBits
                )

                var dynamicStates = [vkDynamicStateViewport, vkDynamicStateScissor]

                dynamicStates.withUnsafeMutableBufferPointer { dynamicBuffer in
                    var dynamicStateInfo = VkPipelineDynamicStateCreateInfo(
                        sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                        pNext: nil,
                        flags: 0,
                        dynamicStateCount: UInt32(dynamicBuffer.count),
                        pDynamicStates: dynamicBuffer.baseAddress
                    )

                    stages.withUnsafeMutableBufferPointer { stageBuffer in
                        withUnsafePointer(to: &colorBlendAttachment) { blendAttachmentPtr in
                            var colorBlending = VkPipelineColorBlendStateCreateInfo(
                                sType:
                                    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                                pNext: nil,
                                flags: 0,
                                logicOpEnable: 0,
                                logicOp: VK_LOGIC_OP_COPY,
                                attachmentCount: 1,
                                pAttachments: blendAttachmentPtr,
                                blendConstants: (0, 0, 0, 0)
                            )

                            var pipelineInfo = VkGraphicsPipelineCreateInfo(
                                sType:
                                    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                                pNext: nil,
                                flags: 0,
                                stageCount: UInt32(stageBuffer.count),
                                pStages: stageBuffer.baseAddress,
                                pVertexInputState: &vertexInputInfo,
                                pInputAssemblyState: &inputAssembly,
                                pTessellationState: nil,
                                pViewportState: &viewportState,
                                pRasterizationState: &rasterizer,
                                pMultisampleState: &multisampling,
                                pDepthStencilState: nil,
                                pColorBlendState: &colorBlending,
                                pDynamicState: &dynamicStateInfo,
                                layout: pipelineLayout,
                                renderPass: renderPass,
                                subpass: 0,
                                basePipelineHandle: nil,
                                basePipelineIndex: -1
                            )

                            vkCheck(
                                vkCreateGraphicsPipelines(
                                    device, pipelineCacheHandle, 1, &pipelineInfo, nil, &pipelineHandle
                                ),
                                "vkCreateGraphicsPipelines"
                            )
                        }
                    }
                }
            }
        }

        guard let graphicsPipeline = pipelineHandle else {
            fail("vkCreateGraphicsPipelines returned null")
        }
        self.graphicsPipeline = graphicsPipeline

        // --- Image Views & Framebuffers ---
        self.imageViews = []
        self.framebuffers = []
        createFramebuffers(
            swapchainImages: swapchainImages,
            swapchainFormat: swapchainFormat,
            swapchainExtent: swapchainExtent
        )

        print("Vulkan graphics pipeline created successfully.")
    }

    func createFramebuffers(
        swapchainImages: [VkImage?],
        swapchainFormat: VkFormat,
        swapchainExtent: VkExtent2D
    ) {
        // Clean up old ones
        destroyFramebuffers()

        imageViews = swapchainImages.map { image -> VkImageView? in
            var viewInfo = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil,
                flags: 0,
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: swapchainFormat,
                components: VkComponentMapping(
                    r: VK_COMPONENT_SWIZZLE_IDENTITY,
                    g: VK_COMPONENT_SWIZZLE_IDENTITY,
                    b: VK_COMPONENT_SWIZZLE_IDENTITY,
                    a: VK_COMPONENT_SWIZZLE_IDENTITY
                ),
                subresourceRange: VkImageSubresourceRange(
                    aspectMask: vkImageAspectColorBit,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1
                )
            )

            var imageView: VkImageView?
            vkCheck(
                vkCreateImageView(device, &viewInfo, nil, &imageView),
                "vkCreateImageView"
            )
            return imageView
        }

        framebuffers = imageViews.map { imageView -> VkFramebuffer? in
            var attachment: VkImageView? = imageView
            var fbInfo = VkFramebufferCreateInfo(
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext: nil,
                flags: 0,
                renderPass: renderPass,
                attachmentCount: 1,
                pAttachments: &attachment,
                width: swapchainExtent.width,
                height: swapchainExtent.height,
                layers: 1
            )

            var framebuffer: VkFramebuffer?
            vkCheck(
                vkCreateFramebuffer(device, &fbInfo, nil, &framebuffer),
                "vkCreateFramebuffer"
            )
            return framebuffer
        }
    }

    func destroyFramebuffers() {
        for fb in framebuffers {
            vkDestroyFramebuffer(device, fb, nil)
        }
        framebuffers = []
        for iv in imageViews {
            vkDestroyImageView(device, iv, nil)
        }
        imageViews = []
    }

    /// Save the pipeline cache to disk for faster startup next time.
    func saveCacheToDisk() {
        guard let cache = pipelineCache else { return }
        var dataSize: Int = 0
        let sizeResult = vkGetPipelineCacheData(device, cache, &dataSize, nil)
        guard sizeResult == VK_SUCCESS, dataSize > 0 else { return }

        var data = [UInt8](repeating: 0, count: dataSize)
        let dataResult = data.withUnsafeMutableBytes { buffer in
            vkGetPipelineCacheData(device, cache, &dataSize, buffer.baseAddress)
        }
        guard dataResult == VK_SUCCESS else { return }

        let path = VulkanPipeline.cacheFilePath
        // Ensure parent directory exists
        let parentDir = parentDirectory(of: path)
        #if os(Windows)
        "cmd".withCString { cmd in
            "/c mkdir \"\(parentDir)\" 2>NUL".withCString { args in
                _ = system("cmd /c mkdir \"\(parentDir)\" 2>NUL")
            }
        }
        #else
        _ = system("mkdir -p '\(parentDir)' 2>/dev/null")
        #endif

        // Write cache data
        let _ = data.withUnsafeBufferPointer { buffer in
            path.withCString { pathPtr in
                let file = fopen(pathPtr, "wb")
                if let file = file {
                    fwrite(buffer.baseAddress, 1, dataSize, file)
                    fclose(file)
                }
            }
        }
    }

    /// Load pipeline cache data from disk, or nil if not available.
    static func loadCacheFromDisk() -> [UInt8]? {
        let path = cacheFilePath
        return path.withCString { pathPtr -> [UInt8]? in
            guard let file = fopen(pathPtr, "rb") else { return nil }
            defer { fclose(file) }

            fseek(file, 0, SEEK_END)
            let size = ftell(file)
            guard size > 0 else { return nil }
            fseek(file, 0, SEEK_SET)

            let fileSize = Int(size)
            var data = [UInt8](repeating: 0, count: fileSize)
            let read = data.withUnsafeMutableBufferPointer { buffer in
                fread(buffer.baseAddress, 1, fileSize, file)
            }
            guard read == fileSize else { return nil }
            return data
        }
    }

    func destroy() {
        saveCacheToDisk()
        destroyFramebuffers()
        vkDestroyPipeline(device, graphicsPipeline, nil)
        if let cache = pipelineCache {
            vkDestroyPipelineCache(device, cache, nil)
        }
        vkDestroyPipelineLayout(device, pipelineLayout, nil)
        vkDestroyRenderPass(device, renderPass, nil)
    }

    // MARK: - Shader Module Helper

    private static func createShaderModule(device: VkDevice, spirv: [UInt8]) -> VkShaderModule? {
        spirv.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return nil }
            let uint32Pointer = base.assumingMemoryBound(to: UInt32.self)
            var createInfo = VkShaderModuleCreateInfo(
                sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                codeSize: rawBuffer.count,
                pCode: uint32Pointer
            )
            var module: VkShaderModule?
            vkCheck(
                vkCreateShaderModule(device, &createInfo, nil, &module),
                "vkCreateShaderModule"
            )
            return module
        }
    }
}
