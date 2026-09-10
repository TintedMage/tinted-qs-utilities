// config/Config.qml

pragma Singleton
import QtQuick

QtObject {
    // ─────────────────────────────────────────────────────────────
    // Global shell configuration
    // ─────────────────────────────────────────────────────────────

    property real uiScale: 1
    property url currentWallpaper: Qt.resolvedUrl("../assets/wallpaper.jpg")

    // ─────────────────────────────────────────────────────────────
    // Modules not migrated yet
    // ─────────────────────────────────────────────────────────────

    /*
    // Bar
    readonly property int innerEdgeMarginX: 20
    readonly property int innerEdgeMarginY: 20
    readonly property int barHeight: 42
    readonly property int floatX: 8
    readonly property int floatY: 8

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
    */
}
