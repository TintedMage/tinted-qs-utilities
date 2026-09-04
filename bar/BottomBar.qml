import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import "components"

PanelWindow {
    anchors {
        bottom: true
        left: true
        right: true
    }
    margins {
        left: Config.floatX
        right: Config.floatX
        bottom: Config.floatY
    }

    implicitHeight: Config.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Colors.colBg

        // topLeftRadius: 12
        // topRightRadius: 12
        radius: 12

        // Left section
        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Config.innerEdgeMarginX
            }
            spacing: 8

            Workspaces {}
        }

        // Center section
        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Clock {}
        }

        // Right section
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Config.innerEdgeMarginX
            }
            spacing: 8

            Text {
                text: "Right"
                color: Colors.colFg
            }
        }
    }
}
