import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

RowLayout {
    spacing: 10

    Repeater {
        model: 6

        delegate: Text {

            font.family: Config.fontFamily
            font.pixelSize: 15

            readonly property int wsId: index + 1
            // Bind to .values to ensure reactivity on workspace creation/deletion
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
            readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
            readonly property bool isUrgent: ws ? ws.urgent : false
            readonly property bool isOccupied: ws ? ws.toplevels.values.length > 0 : false

            text: {
                if (isActive) return ""
                if (isUrgent) return ""
                if (isOccupied) return ""
                return ""
            }

            color: {
                if (isActive) return "#89b4fa"
                if (isUrgent) return "#f38ba8"
                if (isOccupied) return "#cdd6f4"
                return "#6c7086"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`)
            }
        }
    }
}
