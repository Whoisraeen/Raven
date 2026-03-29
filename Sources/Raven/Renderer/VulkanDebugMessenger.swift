import Foundation
import CVulkan
#if canImport(WinSDK)
import WinSDK
#endif

// MARK: - VulkanDebugMessenger

/// Wraps `VK_EXT_debug_utils` to provide runtime validation feedback
/// from the Vulkan driver during development. When enabled, catches API
/// misuse, invalid parameters, and performance warnings.
///
/// Enabled automatically in debug builds when the Vulkan validation layer
/// (`VK_LAYER_KHRONOS_validation`) is installed. Disabled in release builds
/// with zero overhead.
final class VulkanDebugMessenger {
    private var messenger: VkDebugUtilsMessengerEXT?
    private var destroyFunc: PFN_vkDestroyDebugUtilsMessengerEXT?

    /// Whether validation layers are available on this system.
    static func validationLayersAvailable() -> Bool {
        var layerCount: UInt32 = 0
        vkEnumerateInstanceLayerProperties(&layerCount, nil)
        guard layerCount > 0 else { return false }

        var layers = [VkLayerProperties](repeating: VkLayerProperties(), count: Int(layerCount))
        layers.withUnsafeMutableBufferPointer { buffer in
            vkEnumerateInstanceLayerProperties(&layerCount, buffer.baseAddress)
        }

        for layer in layers {
            let name = withUnsafePointer(to: layer.layerName) { ptr in
                String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
            if name == "VK_LAYER_KHRONOS_validation" {
                return true
            }
        }
        return false
    }

    /// Whether debug mode is enabled. True in debug builds by default.
    static var isEnabled: Bool {
        #if false // Temporarily disabled for debugging crash
        return true
        #else
        // Allow opt-in in release via environment variable
        if let env = ProcessInfo.processInfo.environment["RAVEN_VULKAN_DEBUG"] {
            return env == "1" || env.lowercased() == "true"
        }
        return false
        #endif
    }

    /// Create the debug messenger for the given Vulkan instance.
    /// Returns nil if validation layers are not available or not enabled.
    static func create(instance: VkInstance) -> VulkanDebugMessenger? {
        guard isEnabled else {
            RavenLogger.info("Vulkan validation layers: disabled (release build)")
            return nil
        }

        guard validationLayersAvailable() else {
            RavenLogger.info("Vulkan validation layers: not installed (skipping)")
            RavenLogger.info("  Install the Vulkan SDK for validation layer support.")
            return nil
        }

        // Load the creation function
        guard let createFuncRaw = vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT") else {
            RavenLogger.error("Vulkan validation layers: vkCreateDebugUtilsMessengerEXT not found")
            return nil
        }

        let createFunc = unsafeBitCast(createFuncRaw, to: PFN_vkCreateDebugUtilsMessengerEXT.self)

        // Load the destroy function for later cleanup
        let destroyFuncRaw = vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")
        let destroyFunc: PFN_vkDestroyDebugUtilsMessengerEXT? = destroyFuncRaw.map {
            unsafeBitCast($0, to: PFN_vkDestroyDebugUtilsMessengerEXT.self)
        }

        // Configure which message severities and types we want
        let messageSeverity: VkDebugUtilsMessageSeverityFlagsEXT =
            vkDebugUtilsMessageSeverityWarningBitEXT |
            vkDebugUtilsMessageSeverityErrorBitEXT

        let messageType: VkDebugUtilsMessageTypeFlagsEXT =
            vkDebugUtilsMessageTypeGeneralBitEXT |
            vkDebugUtilsMessageTypeValidationBitEXT |
            vkDebugUtilsMessageTypePerformanceBitEXT

        var createInfo = VkDebugUtilsMessengerCreateInfoEXT(
            sType: VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            pNext: nil,
            flags: 0,
            messageSeverity: messageSeverity,
            messageType: messageType,
            pfnUserCallback: vulkanDebugCallback,
            pUserData: nil
        )

        var messengerHandle: VkDebugUtilsMessengerEXT?
        let result = createFunc(instance, &createInfo, nil, &messengerHandle)

        guard result == VK_SUCCESS, let messenger = messengerHandle else {
            RavenLogger.error("Vulkan validation layers: failed to create debug messenger (\(result.rawValue))")
            return nil
        }

        let wrapper = VulkanDebugMessenger()
        wrapper.messenger = messenger
        wrapper.destroyFunc = destroyFunc

        RavenLogger.info("Vulkan validation layers: ENABLED ✓")
        return wrapper
    }

    /// Destroy the debug messenger. Must be called before vkDestroyInstance.
    func destroy(instance: VkInstance) {
        if let messenger = messenger, let destroyFunc = destroyFunc {
            destroyFunc(instance, messenger, nil)
            self.messenger = nil
            RavenLogger.info("Vulkan debug messenger destroyed.")
        }
    }
}

// MARK: - Debug Callback

/// The Vulkan debug callback. This is a C-convention function that receives
/// validation layer messages and prints them with severity tags.
private func vulkanDebugCallback(
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: UnsafePointer<VkDebugUtilsMessengerCallbackDataEXT>?,
    pUserData: UnsafeMutableRawPointer?
) -> VkBool32 {
    guard let data = pCallbackData?.pointee else { return 0 }

    let message = data.pMessage.map { String(cString: $0) } ?? "(no message)"

    // Determine severity tag
    let severityTag: String
    if (UInt32(messageSeverity.rawValue) & vkDebugUtilsMessageSeverityErrorBitEXT) != 0 {
        severityTag = "[VULKAN-ERROR]"
    } else if (UInt32(messageSeverity.rawValue) & vkDebugUtilsMessageSeverityWarningBitEXT) != 0 {
        severityTag = "[VULKAN-WARNING]"
    } else if (UInt32(messageSeverity.rawValue) & vkDebugUtilsMessageSeverityInfoBitEXT) != 0 {
        severityTag = "[VULKAN-INFO]"
    } else {
        severityTag = "[VULKAN-VERBOSE]"
    }

    // Determine type tag
    let typeTag: String
    if (messageTypes & vkDebugUtilsMessageTypePerformanceBitEXT) != 0 {
        typeTag = "PERF"
    } else if (messageTypes & vkDebugUtilsMessageTypeValidationBitEXT) != 0 {
        typeTag = "VALIDATION"
    } else {
        typeTag = "GENERAL"
    }

    RavenLogger.debug("\(severityTag) [\(typeTag)] \(message)")

    // Return VK_FALSE to not abort the call that triggered this message
    return 0
}

// MARK: - Vulkan Debug Utils Constants

let vkDebugUtilsMessageSeverityVerboseBitEXT: VkDebugUtilsMessageSeverityFlagsEXT = 0x00000001
let vkDebugUtilsMessageSeverityInfoBitEXT: VkDebugUtilsMessageSeverityFlagsEXT = 0x00000010
let vkDebugUtilsMessageSeverityWarningBitEXT: VkDebugUtilsMessageSeverityFlagsEXT = 0x00000100
let vkDebugUtilsMessageSeverityErrorBitEXT: VkDebugUtilsMessageSeverityFlagsEXT = 0x00001000

let vkDebugUtilsMessageTypeGeneralBitEXT: VkDebugUtilsMessageTypeFlagsEXT = 0x00000001
let vkDebugUtilsMessageTypeValidationBitEXT: VkDebugUtilsMessageTypeFlagsEXT = 0x00000002
let vkDebugUtilsMessageTypePerformanceBitEXT: VkDebugUtilsMessageTypeFlagsEXT = 0x00000004

