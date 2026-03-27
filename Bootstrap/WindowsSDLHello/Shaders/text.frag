#version 450

layout(set = 0, binding = 0) uniform sampler2D fontAtlas;

layout(location = 0) in vec2 fragUV;
layout(location = 1) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    // Sample the font atlas (single-channel R8)
    float dist = texture(fontAtlas, fragUV).r;

    // SDF-style smoothstep for crisp edges at any scale
    float alpha = smoothstep(0.3, 0.7, dist);

    // Output with the glyph color and SDF-derived alpha
    outColor = vec4(fragColor.rgb, fragColor.a * alpha);
}
