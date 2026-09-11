// modules/panels/PanelConfig.qml

pragma Singleton

import QtQuick
import Quickshell.Wayland
import QtQuick

import qs.config

QtObject {
    readonly property int thickness: 6
    readonly property color borderColor: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, Theme.backgroundOpacity)
    readonly property var wlrlayer: WlrLayer.Top
    readonly property string namespace: "quickshell-panel"
    readonly property int cornerRadius: 12
}
