#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    vec4 fillColor;
    vec2 size;
    float qt_Opacity;
    float panelThickness;   // bar thickness
    float borderThickness;  // thickness of the other three screen edges
    float radius;           // corner radius: desktop cutout + convex corners of drawers
    float smoothing;        // radius of the concave fillet where a drawer meets the bar
    int edgeSide;           // 0: bar on top, 1: bar on bottom
    vec4 w1;                // widgets as (x, y, width, height) in window pixels
    vec4 w2;
    vec4 w3;
};

// Signed distance to a rounded box centred on the origin (negative inside).
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
    r = min(r, min(halfSize.x, halfSize.y));
    vec2 d = abs(p) - halfSize + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

// Union of two shapes with a circular concave fillet of radius r where they meet.
// Unlike smin() this never grows a shape where the two surfaces are far apart
// or exactly flush, so nothing bulges past the bar.
float opRoundUnion(float a, float b, float r) {
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

// "Border dips inward": how far the border's inner wall should retreat (towards the screen
// edge) around a widget that sits INSIDE a border, so the border thins out around it like a
// bay instead of staying a thick slab. Returns 0 for widgets that are as tall as the bar
// or taller, so a flush widget changes nothing. Bar-on-top space, like everything else.
float borderSink(vec2 p, vec4 w, vec2 lo, vec2 hi) {
    if (w.z <= 0.0 || w.w <= 0.0) return 0.0;

    float y   = (edgeSide == 0) ? w.y : size.y - w.y - w.w;
    vec2 ctr  = vec2(w.x + 0.5 * w.z, y + 0.5 * w.w);
    vec2 hs   = 0.5 * w.zw;

    // Small overlap kept between widget and border so the two always join cleanly.
    float preOff = smoothing * (2.0 - sqrt(2.0)) * 0.5;

    // How deep the widget is buried inside each border (0 = not inside it).
    float topPen   = clamp(lo.y - (ctr.y + hs.y) - preOff, 0.0, lo.y);
    float botPen   = clamp((ctr.y - hs.y) - hi.y - preOff, 0.0, size.y - hi.y);
    float leftPen  = clamp(lo.x - (ctr.x + hs.x) - preOff, 0.0, lo.x);
    float rightPen = clamp((ctr.x - hs.x) - hi.x - preOff, 0.0, size.x - hi.x);

    // Only act near the widget: fade out sideways...
    float s    = smoothing * 2.0;
    float latH = 1.0 - smoothstep(0.0, s, max(abs(p.x - ctr.x) - hs.x, 0.0));
    float latV = 1.0 - smoothstep(0.0, s, max(abs(p.y - ctr.y) - hs.y, 0.0));

    // ...and fade out as we move away from the border into the desktop area.
    float topZone   = 1.0 - smoothstep(lo.y, lo.y + smoothing, p.y);
    float botZone   = smoothstep(hi.y - smoothing, hi.y, p.y);
    float leftZone  = 1.0 - smoothstep(lo.x, lo.x + smoothing, p.x);
    float rightZone = smoothstep(hi.x - smoothing, hi.x, p.x);

    return max(max(topPen * latH * topZone, botPen * latH * botZone),
               max(leftPen * latV * leftZone, rightPen * latV * rightZone));
}

// Attach a widget to the bar edge. Everything here is in "bar on top" space.
float attachWidget(float d, vec2 p, vec4 w) {
    if (w.z <= 0.0 || w.w <= 0.0) return d;

    float y      = (edgeSide == 0) ? w.y : size.y - w.y - w.w; // flip for bottom bar
    float bottom = y + w.w;
    float reach  = bottom - panelThickness;                    // how far it sticks out of the bar

    // Still inside the bar's own thickness: it is part of the bar, draw nothing extra.
    if (reach <= 0.5) return d;

    // Extend the box off-screen towards the bar edge so only the far corners are rounded
    // and the widget grows out of the bar as one piece.
    float top = -2.0 * radius;
    vec2 c = vec2(w.x + 0.5 * w.z, 0.5 * (top + bottom));
    vec2 h = vec2(0.5 * w.z, 0.5 * (bottom - top));
    float dw = sdRoundRect(p - c, h, radius);

    // Fillet grows with the drawer, so it appears smoothly instead of popping in.
    return opRoundUnion(d, dw, min(smoothing, reach));
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    if (edgeSide == 1) p.y = size.y - p.y; // work as if the bar is always on top

    // 1. The frame is the WHOLE window minus a rounded "desktop" cutout.
    //    No outer rounding, so the four screen corners are always filled.
    vec2 lo = vec2(borderThickness, panelThickness);
    vec2 hi = vec2(size.x - borderThickness, size.y - borderThickness);
    float dHole = sdRoundRect(p - 0.5 * (lo + hi), 0.5 * (hi - lo), radius);

    // Border dips inward around widgets that sit inside a border (the cutout grows there).
    dHole -= max(max(borderSink(p, w1, lo, hi), borderSink(p, w2, lo, hi)),
                 borderSink(p, w3, lo, hi));
    float d = -dHole;

    // 2. Drawers hanging off the bar.
    d = attachWidget(d, p, w1);
    d = attachWidget(d, p, w2);
    d = attachWidget(d, p, w3);

    float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
    fragColor = fillColor * (alpha * qt_Opacity);
}
