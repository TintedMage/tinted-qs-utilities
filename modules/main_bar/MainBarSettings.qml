// modules/main_bar/MainBarSettings.qml
pragma Singleton
import QtQuick
import qs.core.config

QtObject {
    // Bar position: 0 = top, 1 = bottom. All geometry consumers use this value.
    readonly property int barPosition: 0

    // Shared frame geometry. Keep these values in one place so the QML surface,
    // hit regions, exclusion zones, and Border.frag receive the same dimensions.
    readonly property real barThickness: 38
    readonly property real frameThickness: 6
    readonly property real cornerRadius: Theme.radius
    readonly property real curveSmoothing: 18

    // Horizontal layout values for the three bar zones.
    readonly property real widgetMargin: 24
    readonly property real widgetSpacing: 12

    // The shader receives this color as a uniform; visual theme values stay in Theme.qml.
    readonly property color backgroundColor: Theme.surfaceColor
    readonly property color borderColor: Theme.frameBorderColor
    readonly property real borderWidth: Theme.frameBorderWidth

    // Widget identifiers are resolved by the matching Loader in MainBar.qml.
    readonly property var leftWidgets: ["workspaces"]
    readonly property var centerWidgets: ["clock-calendar"]
    readonly property var rightWidgets: ["app-launcher"]

    // Tiny edge-anchored windows reserve space because the full-screen panel
    // intentionally uses ExclusionMode.Ignore.
    readonly property var exclusionZones: [
    { edge: "top", zone: barPosition === 0 ? barThickness : frameThickness },
    { edge: "bottom", zone: barPosition === 1 ? barThickness : frameThickness },
    { edge: "left", zone: frameThickness },
    { edge: "right", zone: frameThickness }
    ]
}
