// modules/app_launcher/AppLauncherConfig.qml

pragma Singleton
import QtCore
import QtQml

QtObject {
    id: root

    // ─────────────────────────────────────────────────────────────
    // AppLauncher configuration
    // ─────────────────────────────────────────────────────────────

    readonly property int width: 550
    readonly property int height: 600
    readonly property int radius: 18

    readonly property int fontSize: 12
    readonly property int iconSize: 48

    readonly property int padX: 12
    readonly property int padY: 12

    readonly property int maxRecentApps: 5

    // ─────────────────────────────────────────────────────────────
    // Persistent AppLauncher data
    //
    // The .conf file is storage, not a second configuration layer.
    // Static defaults live above; persistent user data lives here.
    // ─────────────────────────────────────────────────────────────

    property var _settings: Settings {
        location: Qt.resolvedUrl("AppLauncher.conf")
        category: "AppLauncher"

        property string recentIdsStr: "[]"
    }

    property string recentIdsStr: _settings.recentIdsStr

    // JSON is used because Settings stores this value as a string.
    readonly property var recentIds: JSON.parse(recentIdsStr || "[]")
}
