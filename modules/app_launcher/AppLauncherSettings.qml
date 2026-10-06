// modules/app_launcher/AppLauncherSettings.qml

pragma Singleton
import QtQuick
import QtCore
import QtQml
import qs.core.config

QtObject {
    id: root

    // AppLauncher configuration

    readonly property int width: 550
    readonly property int height: 650
    readonly property int minWidth: 380
    readonly property int minHeight: 420

    // Gap kept from the screen edges when using the anchor buttons
    readonly property int anchorMargin: 24
    readonly property real radius: Theme.radius
    readonly property real backgroundOpacity: Theme.backgroundOpacity

    readonly property int fontSize: 12
    readonly property int iconSize: 48

    readonly property int padX: 12
    readonly property int padY: 12

    // Extra space to lift the launcher content when the main bar is docked to the bottom.
    readonly property int bottomMargin: 12

    readonly property int maxRecentApps: 5

    // Persistent AppLauncher data
    // The .conf file is storage, not a second configuration layer.
    // Static defaults live above; persistent user data lives here.

    property var _settings: Settings {
        location: Qt.resolvedUrl("app_launcher.conf")
        category: "AppLauncher"

        property string recentIdsStr: "[]"

        // Saved window position. -1 means "not placed yet" (centered on screen).
        property real posX: -1
        property real posY: -1

        // Saved size. 0 means "use the defaults above".
        property real savedW: 0
        property real savedH: 0
    }

    property string recentIdsStr: _settings.recentIdsStr

    // JSON is used because Settings stores this value as a string.
    readonly property var recentIds: JSON.parse(recentIdsStr || "[]")
}
