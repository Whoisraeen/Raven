import CSDL3
import CVulkan

// MARK: - Text Vertex

/// Vertex type for text rendering — includes UV coordinates for atlas sampling.
public struct TextVertex {
    public var posX: Float
    public var posY: Float
    public var u: Float
    public var v: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(_ x: Float, _ y: Float, _ u: Float, _ v: Float,
                _ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        self.posX = x; self.posY = y
        self.u = u; self.v = v
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

/// A text draw command — a positioned string with a color.
public struct TextDrawCommand {
    public var text: String
    public var x: Float
    public var y: Float
    public var scale: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float
    public var maxWidth: Float
    public var clipRect: ClipRect = .none

    public init(text: String, x: Float, y: Float, scale: Float = 1.0,
                r: Float, g: Float, b: Float, a: Float = 1.0, maxWidth: Float = 0, clipRect: ClipRect = .none) {
        self.text = text; self.x = x; self.y = y; self.scale = scale
        self.r = r; self.g = g; self.b = b; self.a = a; self.maxWidth = maxWidth; self.clipRect = clipRect
    }
}

// MARK: - TextRenderer

/// Manages the Vulkan resources for text rendering:
/// - Font atlas texture (VkImage + VkImageView + VkSampler)
/// - Descriptor pool/set (for the texture sampler binding)
/// - Text-specific graphics pipeline (text.vert + text.frag)
/// - Vertex buffer for text quads
public class TextRenderer {
    private let device: VkDevice
    private let physicalDevice: VkPhysicalDevice
    private let queue: VkQueue
    private let commandPool: VkCommandPool

    // Font atlas texture
    private var atlasImage: VkImage?
    private var atlasMemory: VkDeviceMemory?
    private var atlasImageView: VkImageView?
    private var atlasSampler: VkSampler?
    private var currentAtlasWidth: UInt32 = 0
    private var currentAtlasHeight: UInt32 = 0
    private var useDynamicFont: Bool = false

    // Descriptor
    private var descriptorPool: VkDescriptorPool?
    private var descriptorSetLayout: VkDescriptorSetLayout?
    private var descriptorSet: VkDescriptorSet?

    // Pipeline
    private var pipelineLayout: VkPipelineLayout?
    private var graphicsPipeline: VkPipeline?

    // Vertex buffer
    private var vertexBuffer: VulkanBuffer?
    private var vertexCount: UInt32 = 0

    public init(device: VkDevice, physicalDevice: VkPhysicalDevice,
                queue: VkQueue, commandPool: VkCommandPool,
                renderPass: VkRenderPass) {
        self.device = device
        self.physicalDevice = physicalDevice
        self.queue = queue
        self.commandPool = commandPool

        // Try to load the default TTF font via FontManager
        useDynamicFont = FontManager.shared.loadDefaultFont()

        print("[TextRenderer] Creating font atlas...")
        createFontAtlasTexture()
        print("[TextRenderer] Creating descriptor resources...")
        createDescriptorResources()
        print("[TextRenderer] Creating text pipeline...")
        createTextPipeline(renderPass: renderPass)
        print("[TextRenderer] Init complete")
    }

    // MARK: - Font Atlas Texture Creation

    private func createFontAtlasTexture() {
        let atlasData: [UInt8]
        let width: UInt32
        let height: UInt32

        if useDynamicFont {
            // Pre-generate common ASCII glyphs into the atlas
            let fm = FontManager.shared
            for cp: UInt32 in 32...126 {
                let _ = fm.getGlyph(codepoint: cp, fontSize: 16)
            }
            atlasData = fm.currentAtlasData
            width = UInt32(fm.currentAtlasWidth)
            height = UInt32(fm.currentAtlasHeight)
            fm.markAtlasClean()
        } else {
            atlasData = FontAtlas.generateAtlasData()
            width = UInt32(FontAtlas.atlasWidth)
            height = UInt32(FontAtlas.atlasHeight)
        }
        currentAtlasWidth = width
        currentAtlasHeight = height
        let imageSize = VkDeviceSize(atlasData.count)

        // Create staging buffer
        let vkBufferUsageTransferSrc: VkBufferUsageFlags = 0x00000001
        let vkMemoryPropertyHostVisible: VkMemoryPropertyFlags = 0x00000002
        let vkMemoryPropertyHostCoherent: VkMemoryPropertyFlags = 0x00000004
        let staging = VulkanBuffer.create(
            device: device, physicalDevice: physicalDevice,
            size: imageSize, usage: vkBufferUsageTransferSrc,
            memoryPropertyFlags: vkMemoryPropertyHostVisible | vkMemoryPropertyHostCoherent
        )
        staging.upload(device: device, data: atlasData)

        // Create VkImage
        let vkImageUsageSampled: VkImageUsageFlags = 0x00000004
        let vkImageUsageTransferDst: VkImageUsageFlags = 0x00000002
        var imageCreateInfo = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil, flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: VK_FORMAT_R8_UNORM,
            extent: VkExtent3D(width: width, height: height, depth: 1),
            mipLevels: 1, arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: vkImageUsageSampled | vkImageUsageTransferDst,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0, pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )
        vkCheck(vkCreateImage(device, &imageCreateInfo, nil, &atlasImage), "vkCreateImage(fontAtlas)")

        // If memory allocation fails, clean up the image
        var atlasImageOwned = true
        defer {
            if atlasImageOwned {
                vkDestroyImage(device, atlasImage, nil)
                atlasImage = nil
            }
        }

        // Allocate memory
        var memReq = VkMemoryRequirements()
        vkGetImageMemoryRequirements(device, atlasImage, &memReq)

        let vkMemoryPropertyDeviceLocal: VkMemoryPropertyFlags = 0x00000001
        let memTypeIndex = findMemoryType(
            physicalDevice: physicalDevice,
            typeFilter: memReq.memoryTypeBits,
            properties: vkMemoryPropertyDeviceLocal
        )
        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memReq.size,
            memoryTypeIndex: memTypeIndex
        )
        vkCheck(vkAllocateMemory(device, &allocInfo, nil, &atlasMemory), "vkAllocateMemory(fontAtlas)")
        vkCheck(vkBindImageMemory(device, atlasImage, atlasMemory, 0), "vkBindImageMemory(fontAtlas)")
        atlasImageOwned = false // Memory bound successfully, image is now fully owned by the class

        // Transition image layout and copy buffer
        let cmdBuf = beginSingleTimeCommands()

        // Transition: UNDEFINED → TRANSFER_DST_OPTIMAL
        transitionImageLayout(
            cmdBuf: cmdBuf, image: atlasImage!,
            oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
        )

        // Copy buffer to image
        var region = VkBufferImageCopy(
            bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
            imageSubresource: VkImageSubresourceLayers(
                aspectMask: vkImageAspectColorBit,
                mipLevel: 0, baseArrayLayer: 0, layerCount: 1
            ),
            imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
            imageExtent: VkExtent3D(width: width, height: height, depth: 1)
        )
        vkCmdCopyBufferToImage(cmdBuf, staging.buffer, atlasImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region)

        // Transition: TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL
        transitionImageLayout(
            cmdBuf: cmdBuf, image: atlasImage!,
            oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        )

        endSingleTimeCommands(cmdBuf)
        staging.destroy(device: device)

        // Create image view
        var viewCreateInfo = VkImageViewCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext: nil, flags: 0,
            image: atlasImage,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: VK_FORMAT_R8_UNORM,
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
        vkCheck(vkCreateImageView(device, &viewCreateInfo, nil, &atlasImageView), "vkCreateImageView(fontAtlas)")

        // Create sampler
        var samplerCreateInfo = VkSamplerCreateInfo(
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
        vkCheck(vkCreateSampler(device, &samplerCreateInfo, nil, &atlasSampler), "vkCreateSampler(fontAtlas)")
    }

    // MARK: - Descriptor Resources

    private func createDescriptorResources() {
        let vkDescriptorTypeCombinedImageSampler = VkDescriptorType(rawValue: 1)

        // Descriptor set layout
        var layoutBinding = VkDescriptorSetLayoutBinding(
            binding: 0,
            descriptorType: vkDescriptorTypeCombinedImageSampler,
            descriptorCount: 1,
            stageFlags: vkShaderStageFragmentBit,
            pImmutableSamplers: nil
        )
        var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            pNext: nil, flags: 0,
            bindingCount: 1,
            pBindings: &layoutBinding
        )
        vkCheck(vkCreateDescriptorSetLayout(device, &layoutCreateInfo, nil, &descriptorSetLayout),
                "vkCreateDescriptorSetLayout")

        // Descriptor pool
        var poolSize = VkDescriptorPoolSize(
            type: vkDescriptorTypeCombinedImageSampler,
            descriptorCount: 1
        )
        var poolCreateInfo = VkDescriptorPoolCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            pNext: nil, flags: 0,
            maxSets: 1,
            poolSizeCount: 1,
            pPoolSizes: &poolSize
        )
        vkCheck(vkCreateDescriptorPool(device, &poolCreateInfo, nil, &descriptorPool),
                "vkCreateDescriptorPool")

        // Allocate descriptor set
        var allocInfo = VkDescriptorSetAllocateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            pNext: nil,
            descriptorPool: descriptorPool,
            descriptorSetCount: 1,
            pSetLayouts: &descriptorSetLayout
        )
        vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &descriptorSet),
                "vkAllocateDescriptorSets")

        // Update descriptor set with the font atlas
        var imageInfo = VkDescriptorImageInfo(
            sampler: atlasSampler,
            imageView: atlasImageView,
            imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        )
        var writeDescriptor = VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            pNext: nil,
            dstSet: descriptorSet,
            dstBinding: 0, dstArrayElement: 0,
            descriptorCount: 1,
            descriptorType: vkDescriptorTypeCombinedImageSampler,
            pImageInfo: &imageInfo,
            pBufferInfo: nil,
            pTexelBufferView: nil
        )
        vkUpdateDescriptorSets(device, 1, &writeDescriptor, 0, nil)
    }

    // MARK: - Text Pipeline

    private func createTextPipeline(renderPass: VkRenderPass) {
        print("[TextPipeline] Creating layout...")
        // Push constant range (viewport size, same as quad pipeline)
        var pushConstantRange = VkPushConstantRange(
            stageFlags: vkShaderStageVertexBit,
            offset: 0,
            size: UInt32(MemoryLayout<Float>.size * 2)
        )

        // Pipeline layout with descriptor set layout + push constants
        var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            pNext: nil, flags: 0,
            setLayoutCount: 1,
            pSetLayouts: &descriptorSetLayout,
            pushConstantRangeCount: 1,
            pPushConstantRanges: &pushConstantRange
        )
        vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, nil, &pipelineLayout),
                "vkCreatePipelineLayout(text)")

        print("[TextPipeline] Layout created, loading shaders...")
        // Load shaders
        let vertCode = loadSPIRV(named: "text_vert.spv")
        let fragCode = loadSPIRV(named: "text_frag.spv")
        print("[TextPipeline] Shaders loaded (\(vertCode.count)/\(fragCode.count) bytes)")

        let vertModule = createShaderModule(device: device, code: vertCode)
        let fragModule = createShaderModule(device: device, code: fragCode)
        print("[TextPipeline] Shader modules created")
        defer {
            vkDestroyShaderModule(device, vertModule, nil)
            vkDestroyShaderModule(device, fragModule, nil)
        }

        // Shader stages
        let entryPoint = UnsafeMutablePointer<CChar>(mutating: SDL_strdup("main")!)

        var shaderStages: [VkPipelineShaderStageCreateInfo] = [
            VkPipelineShaderStageCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                pNext: nil, flags: 0,
                stage: VK_SHADER_STAGE_VERTEX_BIT,
                module: vertModule,
                pName: entryPoint,
                pSpecializationInfo: nil
            ),
            VkPipelineShaderStageCreateInfo(
                sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                pNext: nil, flags: 0,
                stage: VK_SHADER_STAGE_FRAGMENT_BIT,
                module: fragModule,
                pName: entryPoint,
                pSpecializationInfo: nil
            )
        ]

        // Vertex input: pos(2) + uv(2) + color(4) = 8 floats = 32 bytes
        var bindingDesc = VkVertexInputBindingDescription(
            binding: 0,
            stride: UInt32(MemoryLayout<TextVertex>.stride),
            inputRate: VK_VERTEX_INPUT_RATE_VERTEX
        )

        var attrDescs: [VkVertexInputAttributeDescription] = [
            // location 0: position (vec2)
            VkVertexInputAttributeDescription(
                location: 0, binding: 0,
                format: VK_FORMAT_R32G32_SFLOAT,
                offset: 0
            ),
            // location 1: uv (vec2)
            VkVertexInputAttributeDescription(
                location: 1, binding: 0,
                format: VK_FORMAT_R32G32_SFLOAT,
                offset: UInt32(MemoryLayout<Float>.size * 2)
            ),
            // location 2: color (vec4)
            VkVertexInputAttributeDescription(
                location: 2, binding: 0,
                format: VK_FORMAT_R32G32B32A32_SFLOAT,
                offset: UInt32(MemoryLayout<Float>.size * 4)
            )
        ]

        var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext: nil, flags: 0,
            vertexBindingDescriptionCount: 1,
            pVertexBindingDescriptions: &bindingDesc,
            vertexAttributeDescriptionCount: UInt32(attrDescs.count),
            pVertexAttributeDescriptions: nil  // Set inside withUnsafeMutableBufferPointer
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
            depthBiasEnable: 0, depthBiasConstantFactor: 0, depthBiasClamp: 0, depthBiasSlopeFactor: 0,
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
        let vkBlendFactorSrcAlpha = VkBlendFactor(rawValue: 6)
        let vkBlendFactorOneMinusSrcAlpha = VkBlendFactor(rawValue: 7)
        let vkBlendFactorOne = VkBlendFactor(rawValue: 1)
        let vkBlendFactorZero = VkBlendFactor(rawValue: 0)

        var colorBlendAttachment = VkPipelineColorBlendAttachmentState(
            blendEnable: vkTrueValue,
            srcColorBlendFactor: vkBlendFactorSrcAlpha,
            dstColorBlendFactor: vkBlendFactorOneMinusSrcAlpha,
            colorBlendOp: VK_BLEND_OP_ADD,
            srcAlphaBlendFactor: vkBlendFactorOne,
            dstAlphaBlendFactor: vkBlendFactorZero,
            alphaBlendOp: VK_BLEND_OP_ADD,
            colorWriteMask: vkColorComponentAllBits
        )

        var colorBlending = VkPipelineColorBlendStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            pNext: nil, flags: 0,
            logicOpEnable: 0, logicOp: VK_LOGIC_OP_COPY,
            attachmentCount: 1,
            pAttachments: &colorBlendAttachment,
            blendConstants: (0, 0, 0, 0)
        )

        var dynamicStates: [VkDynamicState] = [vkDynamicStateViewport, vkDynamicStateScissor]
        var dynamicState = VkPipelineDynamicStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            pNext: nil, flags: 0,
            dynamicStateCount: UInt32(dynamicStates.count),
            pDynamicStates: nil  // Set inside withUnsafeMutableBufferPointer
        )

        print("[TextPipeline] Creating graphics pipeline...")
        shaderStages.withUnsafeMutableBufferPointer { stagesPtr in
            attrDescs.withUnsafeMutableBufferPointer { attrPtr in
                dynamicStates.withUnsafeMutableBufferPointer { dynPtr in
                    vertexInputInfo.pVertexAttributeDescriptions = UnsafePointer(attrPtr.baseAddress)
                    dynamicState.pDynamicStates = UnsafePointer(dynPtr.baseAddress)

                    var pipelineInfo = VkGraphicsPipelineCreateInfo(
                        sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                        pNext: nil, flags: 0,
                        stageCount: UInt32(stagesPtr.count),
                        pStages: stagesPtr.baseAddress,
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
                        "vkCreateGraphicsPipelines(text)"
                    )
                }
            }
        }
        print("[TextPipeline] Graphics pipeline created!")

        // Free the SDL_strdup'd entry point name
        SDL_free(entryPoint)
    }

    // MARK: - Generate Text Vertices

    /// Convert text draw commands into vertex data.
    /// Uses FontManager for proportional SDF glyphs when available,
    /// falls back to hardcoded FontAtlas otherwise.
    public func generateVertices(from commands: [TextDrawCommand]) -> [TextVertex] {
        var vertices: [TextVertex] = []

        for cmd in commands {
            if useDynamicFont {
                // Dynamic font path — proportional SDF glyphs with multi-line support
                let fm = FontManager.shared
                let fontSize = cmd.scale * 16.0  // base size 16, scaled
                let metrics = fm.getMetrics(fontSize: fontSize)
                var cursorX = cmd.x
                var cursorY = cmd.y
                var prevCodepoint: UInt32 = 0
                let startX = cmd.x
                let maxWidth = cmd.maxWidth

                // Word-wrap state: buffer glyphs for the current word
                var wordGlyphs: [(cp: UInt32, glyph: GlyphInfo, x: Float)] = []
                var wordStartX = cursorX

                for char in cmd.text {
                    // Handle explicit newlines
                    if char == "\n" {
                        // Flush word buffer
                        for wg in wordGlyphs {
                            emitGlyph(wg.glyph, x: wg.x, y: cursorY, ascent: metrics.ascent, cmd: cmd, into: &vertices)
                        }
                        wordGlyphs.removeAll(keepingCapacity: true)
                        cursorX = startX
                        cursorY += metrics.lineHeight
                        prevCodepoint = 0
                        wordStartX = cursorX
                        continue
                    }

                    let cp = char.unicodeScalars.first.map { UInt32($0.value) } ?? 32

                    // Apply kerning
                    if prevCodepoint != 0 {
                        cursorX += fm.getKerning(cp1: prevCodepoint, cp2: cp, fontSize: fontSize)
                    }

                    guard let glyph = fm.getGlyph(codepoint: cp, fontSize: fontSize) else {
                        prevCodepoint = cp
                        continue
                    }

                    if char == " " {
                        // Space: flush word buffer and advance
                        for wg in wordGlyphs {
                            emitGlyph(wg.glyph, x: wg.x, y: cursorY, ascent: metrics.ascent, cmd: cmd, into: &vertices)
                        }
                        wordGlyphs.removeAll(keepingCapacity: true)
                        cursorX += glyph.advance
                        wordStartX = cursorX
                    } else {
                        // Non-space: check word wrap before adding
                        if maxWidth > 0 && cursorX + glyph.advance - startX > maxWidth && cursorX > startX {
                            // Wrap: move to next line, re-emit word from line start
                            cursorX = startX
                            cursorY += metrics.lineHeight
                            // Re-position word glyphs on the new line
                            var newX = startX
                            for i in wordGlyphs.indices {
                                wordGlyphs[i].x = newX
                                if let g = fm.getGlyph(codepoint: wordGlyphs[i].cp, fontSize: fontSize) {
                                    newX += g.advance
                                }
                            }
                            cursorX = newX
                            wordStartX = startX
                        }
                        wordGlyphs.append((cp: cp, glyph: glyph, x: cursorX))
                        cursorX += glyph.advance
                    }

                    prevCodepoint = cp
                }

                // Flush remaining word
                for wg in wordGlyphs {
                    emitGlyph(wg.glyph, x: wg.x, y: cursorY, ascent: metrics.ascent, cmd: cmd, into: &vertices)
                }
            } else {
                // Fallback: hardcoded bitmap FontAtlas
                let glyphW = Float(FontAtlas.glyphWidth) * cmd.scale
                let glyphH = Float(FontAtlas.glyphHeight) * cmd.scale
                var cursorX = cmd.x

                for char in cmd.text {
                    let (u0, v0, u1, v1) = FontAtlas.uvForChar(char)

                    let x0 = cursorX
                    let y0 = cmd.y
                    let x1 = cursorX + glyphW
                    let y1 = cmd.y + glyphH

                    vertices.append(TextVertex(x0, y0, u0, v0, cmd.r, cmd.g, cmd.b, cmd.a))
                    vertices.append(TextVertex(x0, y1, u0, v1, cmd.r, cmd.g, cmd.b, cmd.a))
                    vertices.append(TextVertex(x1, y1, u1, v1, cmd.r, cmd.g, cmd.b, cmd.a))

                    vertices.append(TextVertex(x0, y0, u0, v0, cmd.r, cmd.g, cmd.b, cmd.a))
                    vertices.append(TextVertex(x1, y1, u1, v1, cmd.r, cmd.g, cmd.b, cmd.a))
                    vertices.append(TextVertex(x1, y0, u1, v0, cmd.r, cmd.g, cmd.b, cmd.a))

                    cursorX += glyphW
                }
            }
        }

        return vertices
    }

    /// Emit two triangles for a single glyph at the given position.
    private func emitGlyph(_ glyph: GlyphInfo, x: Float, y: Float, ascent: Float, cmd: TextDrawCommand, into vertices: inout [TextVertex]) {
        guard glyph.width > 0 && glyph.height > 0 else { return }
        let x0 = x + glyph.xOffset
        let y0 = y + ascent + glyph.yOffset
        let x1 = x0 + glyph.width
        let y1 = y0 + glyph.height

        vertices.append(TextVertex(x0, y0, glyph.u0, glyph.v0, cmd.r, cmd.g, cmd.b, cmd.a))
        vertices.append(TextVertex(x0, y1, glyph.u0, glyph.v1, cmd.r, cmd.g, cmd.b, cmd.a))
        vertices.append(TextVertex(x1, y1, glyph.u1, glyph.v1, cmd.r, cmd.g, cmd.b, cmd.a))

        vertices.append(TextVertex(x0, y0, glyph.u0, glyph.v0, cmd.r, cmd.g, cmd.b, cmd.a))
        vertices.append(TextVertex(x1, y1, glyph.u1, glyph.v1, cmd.r, cmd.g, cmd.b, cmd.a))
        vertices.append(TextVertex(x1, y0, glyph.u1, glyph.v0, cmd.r, cmd.g, cmd.b, cmd.a))
    }

    /// Re-upload the atlas texture if FontManager has new glyphs.
    public func updateAtlasIfNeeded() {
        guard useDynamicFont, FontManager.shared.isAtlasDirty else { return }

        let fm = FontManager.shared
        let newWidth = UInt32(fm.currentAtlasWidth)
        let newHeight = UInt32(fm.currentAtlasHeight)
        let atlasData = fm.currentAtlasData
        let imageSize = VkDeviceSize(atlasData.count)

        // If atlas grew, recreate the entire image/view/descriptor
        if newWidth != currentAtlasWidth || newHeight != currentAtlasHeight {
            vkCheck(vkDeviceWaitIdle(device), "vkDeviceWaitIdle(atlasGrow)")

            // Destroy old
            vkDestroyImageView(device, atlasImageView, nil)
            vkDestroyImage(device, atlasImage, nil)
            vkFreeMemory(device, atlasMemory, nil)

            currentAtlasWidth = newWidth
            currentAtlasHeight = newHeight

            // Recreate VkImage
            let vkImageUsageSampled: VkImageUsageFlags = 0x00000004
            let vkImageUsageTransferDst: VkImageUsageFlags = 0x00000002
            var imageCreateInfo = VkImageCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
                pNext: nil, flags: 0,
                imageType: VK_IMAGE_TYPE_2D,
                format: VK_FORMAT_R8_UNORM,
                extent: VkExtent3D(width: newWidth, height: newHeight, depth: 1),
                mipLevels: 1, arrayLayers: 1,
                samples: VK_SAMPLE_COUNT_1_BIT,
                tiling: VK_IMAGE_TILING_OPTIMAL,
                usage: vkImageUsageSampled | vkImageUsageTransferDst,
                sharingMode: VK_SHARING_MODE_EXCLUSIVE,
                queueFamilyIndexCount: 0, pQueueFamilyIndices: nil,
                initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
            )
            vkCheck(vkCreateImage(device, &imageCreateInfo, nil, &atlasImage), "vkCreateImage(atlasGrow)")

            // If memory allocation fails, clean up the new image
            var growImageOwned = true
            defer {
                if growImageOwned {
                    vkDestroyImage(device, atlasImage, nil)
                    atlasImage = nil
                }
            }

            var memReq = VkMemoryRequirements()
            vkGetImageMemoryRequirements(device, atlasImage, &memReq)
            let vkMemoryPropertyDeviceLocal: VkMemoryPropertyFlags = 0x00000001
            let memTypeIndex = findMemoryType(
                physicalDevice: physicalDevice,
                typeFilter: memReq.memoryTypeBits,
                properties: vkMemoryPropertyDeviceLocal
            )
            var allocInfo = VkMemoryAllocateInfo(
                sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                pNext: nil,
                allocationSize: memReq.size,
                memoryTypeIndex: memTypeIndex
            )
            vkCheck(vkAllocateMemory(device, &allocInfo, nil, &atlasMemory), "vkAllocateMemory(atlasGrow)")
            vkCheck(vkBindImageMemory(device, atlasImage, atlasMemory, 0), "vkBindImageMemory(atlasGrow)")
            growImageOwned = false // Memory bound successfully

            // Upload data
            let vkBufferUsageTransferSrc: VkBufferUsageFlags = 0x00000001
            let vkMemoryPropertyHostVisible: VkMemoryPropertyFlags = 0x00000002
            let vkMemoryPropertyHostCoherent: VkMemoryPropertyFlags = 0x00000004
            let staging = VulkanBuffer.create(
                device: device, physicalDevice: physicalDevice,
                size: imageSize, usage: vkBufferUsageTransferSrc,
                memoryPropertyFlags: vkMemoryPropertyHostVisible | vkMemoryPropertyHostCoherent
            )
            staging.upload(device: device, data: atlasData)

            let cmdBuf = beginSingleTimeCommands()
            transitionImageLayout(cmdBuf: cmdBuf, image: atlasImage!,
                                  oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                                  newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)

            var region = VkBufferImageCopy(
                bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
                imageSubresource: VkImageSubresourceLayers(
                    aspectMask: vkImageAspectColorBit,
                    mipLevel: 0, baseArrayLayer: 0, layerCount: 1
                ),
                imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
                imageExtent: VkExtent3D(width: newWidth, height: newHeight, depth: 1)
            )
            vkCmdCopyBufferToImage(cmdBuf, staging.buffer, atlasImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region)

            transitionImageLayout(cmdBuf: cmdBuf, image: atlasImage!,
                                  oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                                  newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

            endSingleTimeCommands(cmdBuf)
            staging.destroy(device: device)

            // Recreate image view
            var viewCreateInfo = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil, flags: 0,
                image: atlasImage,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: VK_FORMAT_R8_UNORM,
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
            vkCheck(vkCreateImageView(device, &viewCreateInfo, nil, &atlasImageView), "vkCreateImageView(atlasGrow)")

            // Update descriptor set
            let vkDescriptorTypeCombinedImageSampler = VkDescriptorType(rawValue: 1)
            var imageInfo = VkDescriptorImageInfo(
                sampler: atlasSampler,
                imageView: atlasImageView,
                imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
            )
            var writeDescriptor = VkWriteDescriptorSet(
                sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                pNext: nil,
                dstSet: descriptorSet,
                dstBinding: 0, dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: vkDescriptorTypeCombinedImageSampler,
                pImageInfo: &imageInfo,
                pBufferInfo: nil,
                pTexelBufferView: nil
            )
            vkUpdateDescriptorSets(device, 1, &writeDescriptor, 0, nil)

        } else {
            // Same size — just re-upload data
            let vkBufferUsageTransferSrc: VkBufferUsageFlags = 0x00000001
            let vkMemoryPropertyHostVisible: VkMemoryPropertyFlags = 0x00000002
            let vkMemoryPropertyHostCoherent: VkMemoryPropertyFlags = 0x00000004
            let staging = VulkanBuffer.create(
                device: device, physicalDevice: physicalDevice,
                size: imageSize, usage: vkBufferUsageTransferSrc,
                memoryPropertyFlags: vkMemoryPropertyHostVisible | vkMemoryPropertyHostCoherent
            )
            staging.upload(device: device, data: atlasData)

            let cmdBuf = beginSingleTimeCommands()
            transitionImageLayout(cmdBuf: cmdBuf, image: atlasImage!,
                                  oldLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                                  newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)

            var region = VkBufferImageCopy(
                bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
                imageSubresource: VkImageSubresourceLayers(
                    aspectMask: vkImageAspectColorBit,
                    mipLevel: 0, baseArrayLayer: 0, layerCount: 1
                ),
                imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
                imageExtent: VkExtent3D(width: newWidth, height: newHeight, depth: 1)
            )
            vkCmdCopyBufferToImage(cmdBuf, staging.buffer, atlasImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region)

            transitionImageLayout(cmdBuf: cmdBuf, image: atlasImage!,
                                  oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                                  newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

            endSingleTimeCommands(cmdBuf)
            staging.destroy(device: device)
        }

        fm.markAtlasClean()
    }

    // MARK: - Record Text Draw Commands

    /// Record the text drawing commands into a command buffer.
    /// Must be called within an active render pass.
    public func recordDraw(commandBuffer: VkCommandBuffer, commands: [TextDrawCommand],
                           viewportSize: (Float, Float)) {
        if commands.isEmpty { return }

        let vertices = generateVertices(from: commands)
        if vertices.isEmpty { return }

        // Upload to vertex buffer
        let dataSize = VkDeviceSize(MemoryLayout<TextVertex>.stride * vertices.count)
        if vertexBuffer == nil || vertexBuffer!.size < dataSize {
            vertexBuffer?.destroy(device: device)
            let vkBufferUsageVertexBit: VkBufferUsageFlags = 0x00000080
            let vkMemoryPropertyHostVisibleBit: VkMemoryPropertyFlags = 0x00000002
            let vkMemoryPropertyHostCoherentBit: VkMemoryPropertyFlags = 0x00000004
            let allocSize = max(dataSize, 1024) * 2
            vertexBuffer = VulkanBuffer.create(
                device: device, physicalDevice: physicalDevice,
                size: allocSize, usage: vkBufferUsageVertexBit,
                memoryPropertyFlags: vkMemoryPropertyHostVisibleBit | vkMemoryPropertyHostCoherentBit
            )
        }
        vertexBuffer!.upload(device: device, data: vertices)
        vertexCount = UInt32(vertices.count)

        // Bind text pipeline
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)

        // Bind descriptor set (font atlas texture)
        var dsHandle: VkDescriptorSet? = descriptorSet
        withUnsafePointer(to: &dsHandle) { dsPtr in
            vkCmdBindDescriptorSets(
                commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
                pipelineLayout, 0, 1, dsPtr, 0, nil
            )
        }

        // Push constants (viewport size)
        var vps = viewportSize
        withUnsafePointer(to: &vps) { ptr in
            vkCmdPushConstants(commandBuffer, pipelineLayout, vkShaderStageVertexBit,
                               0, UInt32(MemoryLayout<Float>.size * 2), ptr)
        }

        // Bind vertex buffer and draw
        if let vb = vertexBuffer?.buffer {
            var bufHandle: VkBuffer? = vb
            var offset: VkDeviceSize = 0
            withUnsafePointer(to: &bufHandle) { bufPtr in
                vkCmdBindVertexBuffers(commandBuffer, 0, 1, bufPtr, &offset)
            }
            vkCmdDraw(commandBuffer, vertexCount, 1, 0, 0)
        }
    }

    // MARK: - Single-Time Commands

    private func beginSingleTimeCommands() -> VkCommandBuffer {
        var allocInfo = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1
        )
        var cmdBuf: VkCommandBuffer?
        vkCheck(vkAllocateCommandBuffers(device, &allocInfo, &cmdBuf), "vkAllocateCommandBuffers(single)")

        var beginInfo = VkCommandBufferBeginInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext: nil,
            flags: vkCommandBufferOneTimeSubmitBit,
            pInheritanceInfo: nil
        )
        vkCheck(vkBeginCommandBuffer(cmdBuf, &beginInfo), "vkBeginCommandBuffer(single)")
        return cmdBuf!
    }

    private func endSingleTimeCommands(_ cmdBuf: VkCommandBuffer) {
        vkCheck(vkEndCommandBuffer(cmdBuf), "vkEndCommandBuffer(single)")

        var cmdBufHandle: VkCommandBuffer? = cmdBuf
        var submitInfo = VkSubmitInfo(
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext: nil,
            waitSemaphoreCount: 0, pWaitSemaphores: nil, pWaitDstStageMask: nil,
            commandBufferCount: 1, pCommandBuffers: &cmdBufHandle,
            signalSemaphoreCount: 0, pSignalSemaphores: nil
        )
        vkCheck(vkQueueSubmit(queue, 1, &submitInfo, nil), "vkQueueSubmit(single)")
        vkCheck(vkQueueWaitIdle(queue), "vkQueueWaitIdle(single)")

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
            srcAccess = 0
            dstAccess = vkAccessTransferWriteBit
            srcStage = vkPipelineStageTopOfPipeBit
            dstStage = vkPipelineStageTransferBit
        } else if oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL {
            srcAccess = vkAccessTransferWriteBit
            dstAccess = 0x00000020  // VK_ACCESS_SHADER_READ_BIT
            srcStage = vkPipelineStageTransferBit
            dstStage = 0x00000080  // VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
        } else if oldLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
            srcAccess = 0x00000020  // VK_ACCESS_SHADER_READ_BIT
            dstAccess = vkAccessTransferWriteBit
            srcStage = 0x00000080  // VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
            dstStage = vkPipelineStageTransferBit
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
        vkDestroyPipeline(device, graphicsPipeline, nil)
        vkDestroyPipelineLayout(device, pipelineLayout, nil)
        vkDestroyDescriptorPool(device, descriptorPool, nil)
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        vkDestroySampler(device, atlasSampler, nil)
        vkDestroyImageView(device, atlasImageView, nil)
        vkDestroyImage(device, atlasImage, nil)
        vkFreeMemory(device, atlasMemory, nil)
    }
}

// MARK: - Shader Module Helper

private func createShaderModule(device: VkDevice, code: [UInt8]) -> VkShaderModule? {
    code.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return nil }
        let uint32Pointer = base.assumingMemoryBound(to: UInt32.self)
        var createInfo = VkShaderModuleCreateInfo(
            sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            pNext: nil, flags: 0,
            codeSize: rawBuffer.count,
            pCode: uint32Pointer
        )
        var shaderModule: VkShaderModule?
        vkCheck(vkCreateShaderModule(device, &createInfo, nil, &shaderModule),
                "vkCreateShaderModule(text)")
        return shaderModule
    }
}
