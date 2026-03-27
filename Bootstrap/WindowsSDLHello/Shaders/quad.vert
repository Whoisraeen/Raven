#version 450

layout(push_constant) uniform PushConstants {
    vec2 viewportSize;
} pc;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec4 inColor;

layout(location = 0) out vec4 fragColor;

void main() {
    // Convert pixel coordinates to Vulkan clip space [-1, 1]
    // Origin is top-left (0,0), bottom-right is (viewportSize.x, viewportSize.y)
    vec2 clipPos = (inPosition / pc.viewportSize) * 2.0 - 1.0;
    gl_Position = vec4(clipPos, 0.0, 1.0);
    fragColor = inColor;
}
