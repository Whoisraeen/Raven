#version 450

layout(push_constant) uniform PushConstants {
    vec2 viewportSize;
} pc;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec4 inColor;

layout(location = 0) out vec2 fragUV;
layout(location = 1) out vec4 fragColor;

void main() {
    vec2 clipPos = (inPosition / pc.viewportSize) * 2.0 - 1.0;
    gl_Position = vec4(clipPos, 0.0, 1.0);
    fragUV = inUV;
    fragColor = inColor;
}
