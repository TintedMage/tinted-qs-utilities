// core/config/Theme.qml

pragma Singleton
import QtQuick

QtObject {
    // Global visual theme

    readonly property string fontFamily: "MesloLGS Nerd Font Propo"
    readonly property int fontSize: 14

    readonly property color colBg: "#11111b"
    readonly property color colBgDim: "#181825"
    readonly property color colFg: "#cdd6f4"
    readonly property color colFgDim: "#a6adc8"
    readonly property color colAccent: "#89b4fa"
    readonly property color colBlack: "#010101"
    readonly property color colWhite: "#ffffff"
    readonly property real radius: 10

    // Global translucent surface opacity.
    property real backgroundOpacity: 0.8
    readonly property color surfaceColor: Qt.rgba(
        colBg.r,
        colBg.g,
        colBg.b,
        backgroundOpacity
    )

    readonly property color frameBorderColor: Qt.rgba(
        colFg.r,
        colFg.g,
        colFg.b,
        0.2
    )
    readonly property real frameBorderWidth: 2
}
