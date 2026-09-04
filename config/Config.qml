pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "MesloLGS Nerd Font Propo"
    readonly property int fontSize: 14
    property string currentWallpaper: Qt.resolvedUrl("assets/current_wallpaper.jpg")

    property real bgOpacity: 0.8

    // Bar
    readonly property int innerEdgeMarginX: 20
    readonly property int innerEdgeMarginY: 20
    readonly property int barHeight: 42
    readonly property int floatX: 8
    readonly property int floatY: 8

    // App Launcher
    property int launcherWidth: 550
    property int launcherHeight: 600
    property int launcherRadius: 18
    property int launcherFontSize: 12
    property int launcherIconSize: 48
    property int launcherPadX: 12
    property int launcherPadY: 12
    property real uiScale: 1

    // Clipboard
    readonly property int clipboardWidth: 360
    readonly property int clipboardHeight: 480
    readonly property int clipboardRadius: 18
    readonly property int clipboardPadX: 20
    readonly property int clipboardPadY: 20
    readonly property int clipboardItemHeight: 50
    readonly property int clipboardItemSpacing: 10
    readonly property int clipboardHeaderFontSize: 13
    readonly property int clipboardItemFontSize: 11
    readonly property int clipboardMaxItems: 50
    readonly property real clipboardYOffsetRatio: 0.20
}
