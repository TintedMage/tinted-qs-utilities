#version 440
// modules/main_bar/shaders/Border.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// QML fills this block from MainBar.qml. Keep names and order synchronized
// with the ShaderEffect properties and rebuild Border.frag.qsb after changes.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    vec4 backgroundColor;
    vec4 borderColor;
    vec2 size;
    float qt_Opacity;
    float barThickness;
    float borderThickness;
    float radius;
    float smoothing;
    float borderWidth;
    int barPosition;
    vec4 launcher;
    float launcherRadius;
};

// Signed distance for a rounded rectangle. Negative values are inside.
float sdRoundRect(vec2 point, vec2 halfSize, float cornerRadius) {
    cornerRadius = min(cornerRadius, min(halfSize.x, halfSize.y));
    vec2 distance = abs(point) - halfSize + vec2(cornerRadius);
    return min(max(distance.x, distance.y), 0.0) + length(max(distance, 0.0)) - cornerRadius;
}

// Smoothly joins two shapes without changing either shape far from the join.
float roundUnion(float first, float second, float blendRadius) {
    vec2 distance = max(vec2(blendRadius - first, blendRadius - second), vec2(0.0));
    return max(blendRadius, min(first, second)) - length(distance);
}

// Attach the launcher to the bottom edge. Its geometry is animated in QML;
// the radius stays fixed so the corners do not twitch during the animation.
float attachLauncher(float frameDistance, vec2 point) {
    if (launcher.z <= 0.0 || launcher.w <= 0.0)
        return frameDistance;

    float innerBottom = size.y - ((barPosition == 1) ? barThickness : borderThickness);
    float reach = max(innerBottom - launcher.y, 0.0);

    if (reach <= 0.5)
        return frameDistance;

    float bottom = size.y + 2.0 * launcherRadius;
    vec2 center = vec2(launcher.x + 0.5 * launcher.z, 0.5 * (launcher.y + bottom));
    vec2 halfSize = vec2(0.5 * launcher.z, 0.5 * (bottom - launcher.y));
    float launcherDistance = sdRoundRect(point - center, halfSize, launcherRadius);

    return roundUnion(frameDistance, launcherDistance, min(smoothing, reach));
}

void main() {
    // Convert normalized texture coordinates into window pixels.
    vec2 pixel = qt_TexCoord0 * size;
    vec2 framePixel = pixel;

    if (barPosition == 1)
        framePixel.y = size.y - framePixel.y;

    // Build the frame by subtracting the rounded desktop opening.
    vec2 innerLow = vec2(borderThickness, barThickness);
    vec2 innerHigh = vec2(size.x - borderThickness, size.y - borderThickness);
    vec2 frameCenter = 0.5 * (innerLow + innerHigh);
    vec2 frameHalfSize = 0.5 * (innerHigh - innerLow);
    float desktopDistance = sdRoundRect(framePixel - frameCenter, frameHalfSize, radius);
    float frameDistance = -desktopDistance;

    // Connected popup surfaces are added after the frame so their joins share
    // the same smoothing radius and remain part of one continuous surface.
    frameDistance = attachLauncher(frameDistance, pixel);

    // Convert the signed distance to antialiased alpha.
    float alpha = 1.0 - smoothstep(-0.5, 0.5, frameDistance);
    float outline = borderWidth > 0.0
        ? 1.0 - smoothstep(0.0, borderWidth, abs(frameDistance))
        : 0.0;
    vec4 surface = mix(backgroundColor, borderColor, outline);
    fragColor = surface * (alpha * qt_Opacity);
}
