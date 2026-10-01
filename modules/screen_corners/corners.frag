#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uRadius;
    vec2 uSize;
    vec4 uBorders; // x: top, y: right, z: bottom, w: left
    vec4 uSlants;  // x: top, y: right, z: bottom, w: left
    vec4 uColor;
};

// Evaluates distance for a single corner (positive = border, negative = screen interior)
float cornerDist(float p1, float p2, float r) {
    if (p1 <= 0.0) return -p1;
    if (p2 <= 0.0) return -p2;
    vec2 q = max(vec2(0.0), vec2(r) - vec2(p1, p2));
    return length(q) - r;
}

void main() {
    vec2 pos = qt_TexCoord0 * uSize;
    vec2 center = uSize * 0.5;

    float nx = (pos.x - center.x) / uSize.x;
    float ny = (pos.y - center.y) / uSize.y;

    // Slanted border line positions
    float topY    = uBorders.x + nx * uSlants.x;
    float rightX  = uSize.x - uBorders.y - ny * uSlants.y;
    float bottomY = uSize.y - uBorders.z - nx * uSlants.z;
    float leftX   = uBorders.w + ny * uSlants.w;

    // Distances pointing inward toward the screen center
    float p_top    = pos.y - topY;
    float p_right  = rightX - pos.x;
    float p_bottom = bottomY - pos.y;
    float p_left   = pos.x - leftX;

    // Evaluate distance for all 4 corners
    float d_tl = cornerDist(p_left, p_top, uRadius);
    float d_tr = cornerDist(p_right, p_top, uRadius);
    float d_br = cornerDist(p_right, p_bottom, uRadius);
    float d_bl = cornerDist(p_left, p_bottom, uRadius);

    // Combine regions
    float d = max(max(d_tl, d_tr), max(d_br, d_bl));

    float alpha = smoothstep(-0.75, 0.75, d);
    fragColor = uColor * alpha * qt_Opacity;
}
