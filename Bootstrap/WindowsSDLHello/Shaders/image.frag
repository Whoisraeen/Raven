#version 450

layout(set = 0, binding = 0) uniform sampler2D textureSampler;

layout(location = 0) in vec2 fragUV;
layout(location = 1) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    // Directly sample the RGBA texture
    vec4 texColor = texture(textureSampler, fragUV);

    // Apply vertex color as tint and opacity
    outColor = texColor * fragColor;
}
