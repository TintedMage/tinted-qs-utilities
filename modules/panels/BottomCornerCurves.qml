// modules/panels/BottomCornerCurves.qml

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"

PanelWindow {
    id: root

    readonly property int cornerRadius: PanelConfig.cornerRadius
    readonly property color barColor: PanelConfig.borderColor
    readonly property var wlrlayer: PanelConfig.wlrlayer
    readonly property string namespace: PanelConfig.namespace

    color: "transparent"

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusiveZone: 0
    implicitHeight: cornerRadius

    WlrLayershell.layer: wlrlayer
    WlrLayershell.namespace: namespace

    ConcaveCurves {
        anchors.top: parent.top
        anchors.left: parent.left
        radius: root.cornerRadius
        color: root.barColor
        isTop: false
    }

    ConcaveCurves {
        anchors.top: parent.top
        anchors.right: parent.right
        radius: root.cornerRadius
        color: root.barColor
        isTop: false
        mirrored: true
    }
}
