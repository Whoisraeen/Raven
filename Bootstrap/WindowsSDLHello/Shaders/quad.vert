#version 450

layout(push_constant) uniform PushConstants {
    vec2 viewportSize;
} pc;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec4 inColor;
layout(location = 2) in vec2 inRectMin;
layout(location = 3) in vec2 inRectMax;
layout(location = 4) in float inCornerRadius;
layout(location = 5) in float inShadowRadius;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec2 fragPos;
layout(location = 2) out vec2 rectMin;
layout(location = 3) out vec2 rectMax;
layout(location = 4) out float cornerRadius;
layout(location = 5) out float shadowRadius;

void main() {
    // Convert pixel coordinates to Vulkan clip space [-1, 1]
    vec2 clipPos = (inPosition / pc.viewportSize) * 2.0 - 1.0;
    gl_Position = vec4(clipPos, 0.0, 1.0);
    
    fragColor = inColor;
    fragPos = inPosition;
    rectMin = inRectMin;
    rectMax = inRectMax;
    cornerRadius = inCornerRadius;
    shadowRadius = inShadowRadius;
}
