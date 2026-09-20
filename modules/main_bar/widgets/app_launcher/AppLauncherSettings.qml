// modules/main_bar/widgets/app_launcher/AppLauncherSettings.qml

pragma Singleton
import QtQuick
import QtCore
import QtQml
import qs.core.config

QtObject {
    id: root

    // AppLauncher configuration

    readonly property int width: 550
    readonly property int height: 578
    readonly property real radius: Theme.radius
    readonly property color fallbackBackgroundColor: "transparent"

    readonly property int fontSize: 12
    readonly property int iconSize: 48

    readonly property int padX: 12
    readonly property int padY: 12

    readonly property int maxRecentApps: 5

    // Persistent AppLauncher data
    // The .conf file is storage, not a second configuration layer.
    // Static defaults live above; persistent user data lives here.

    property var _settings: Settings {
        location: Qt.resolvedUrl("AppLauncher.conf")
        category: "AppLauncher"

        property string recentIdsStr: "[]"
    }

    property string recentIdsStr: _settings.recentIdsStr

    // JSON is used because Settings stores this value as a string.
    readonly property var recentIds: JSON.parse(recentIdsStr || "[]")
}
