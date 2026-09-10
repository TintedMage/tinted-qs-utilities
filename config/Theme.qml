// config/Theme.qml

pragma Singleton
import QtQuick

QtObject {
    // ─────────────────────────────────────────────────────────────
    // Global visual theme
    // ─────────────────────────────────────────────────────────────

    readonly property string fontFamily: "MesloLGS Nerd Font Propo"
    readonly property int fontSize: 14

    readonly property color colBg: "#11111b"
    readonly property color colBgDim: "#181825"
    readonly property color colFg: "#cdd6f4"
    readonly property color colFgDim: "#a6adc8"
    readonly property color colAccent: "#89b4fa"
    readonly property color colBlack: "#010101"
    readonly property color colWhite: "#ffffff"

    // Global translucent surface opacity.
    property real backgroundOpacity: 0.8
}
