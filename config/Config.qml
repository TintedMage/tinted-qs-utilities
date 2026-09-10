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
    */
}
