// modules/screen_corners/Corners.qml

import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData
        screen: modelData
        color: "transparent"

        WlrLayershell.namespace: "screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Per-edge border widths (top, right, bottom, left)
        readonly property real topWidth: 0.5
        readonly property real rightWidth: 1.2
        readonly property real bottomWidth: 2
        readonly property real leftWidth: 1.5

        // End-to-end pixel tilt offsets per edge
        readonly property real topSlant: -0.8
        readonly property real rightSlant: 2.5
        readonly property real bottomSlant: 2
        readonly property real leftSlant: 0

        readonly property int radius: 12
        readonly property color borderColor: "black"

        ShaderEffect {
            anchors.fill: parent
            fragmentShader: "corners.frag.qsb"

            property real uRadius: root.radius
            property vector2d uSize: Qt.vector2d(parent.width, parent.height)
            property vector4d uBorders: Qt.vector4d(root.topWidth, root.rightWidth, root.bottomWidth, root.leftWidth)
            property vector4d uSlants: Qt.vector4d(root.topSlant, root.rightSlant, root.bottomSlant, root.leftSlant)
            property color uColor: root.borderColor
        }
    }
}
