#version 450

layout(set = 0, binding = 0) uniform sampler2D fontAtlas;

layout(location = 0) in vec2 fragUV;
layout(location = 1) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    // Sample the font atlas (single-channel R8)
    float dist = texture(fontAtlas, fragUV).r;

    // SDF edge at 180/255 ≈ 0.706. Use screen-space derivatives for
    // pixel-perfect anti-aliasing at any scale.
    float edge = 180.0 / 255.0;
    float w = fwidth(dist) * 0.5;
    float alpha = smoothstep(edge - w, edge + w, dist);

    // Output with the glyph color and SDF-derived alpha
    outColor = vec4(fragColor.rgb, fragColor.a * alpha);
}
