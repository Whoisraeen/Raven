#version 450

layout(location = 0) in vec4 fragColor;
layout(location = 1) in vec2 fragPos;
layout(location = 2) in vec2 rectMin;
layout(location = 3) in vec2 rectMax;
layout(location = 4) in float cornerRadius;
layout(location = 5) in float shadowRadius;

layout(location = 0) out vec4 outColor;

// SDF for a rounded box
float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 center = (rectMin + rectMax) * 0.5;
    vec2 halfSize = (rectMax - rectMin) * 0.5;
    
    float dist = roundedBoxSDF(fragPos - center, halfSize, cornerRadius);
    
    float alpha;
    if (shadowRadius > 0.0) {
        // Soft shadow transition
        // Map dist range [-shadowRadius, shadowRadius] to alpha [1, 0]
        alpha = 1.0 - smoothstep(-shadowRadius, shadowRadius, dist);
    } else {
        // Sharp shape with antialiasing
        float smoothing = fwidth(dist);
        alpha = 1.0 - smoothstep(-smoothing, smoothing, dist);
    }
    
    if (alpha <= 0.0) discard;
    
    outColor = vec4(fragColor.rgb, fragColor.a * alpha);
}
