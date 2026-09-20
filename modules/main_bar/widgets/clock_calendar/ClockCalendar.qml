// modules/main_bar/widgets/clock_calendar/ClockCalendar.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.config

Item {
    id: root

    property var panelScreen
    // Bar position: 0 = top, 1 = bottom.
    property int barPosition: 0
    property real barThickness: 0
    property bool calendarVisible: false

    implicitWidth: 150
    implicitHeight: 38

    property date now: new Date()
    readonly property string timeText: Qt.formatDateTime(now, "hh:mm")
    readonly property string dateText: Qt.formatDateTime(now, "ddd, dd MMM")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Text {
        anchors.centerIn: parent
        color: Theme.colFg
        text: root.timeText + "  " + root.dateText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.calendarVisible = !root.calendarVisible
    }

    PanelWindow {
        id: calendarWindow
        visible: root.calendarVisible
        screen: root.panelScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-clock-calendar"

        anchors {
            top: root.barPosition === 0
            bottom: root.barPosition === 1
        }
        margins {
            top: root.barPosition === 0 ? root.barThickness + 8 : 0
            bottom: root.barPosition === 1 ? root.barThickness + 8 : 0
        }
        implicitWidth: 300
        implicitHeight: 250

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, Theme.backgroundOpacity)
            radius: Theme.radius
            border.color: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.18)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    width: parent.width
                    text: Qt.formatDateTime(root.now, "MMMM yyyy")
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        Text {
                            width: (parent.width - 24) / 7
                            text: modelData
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    spacing: 4

                    Repeater {
                        model: root.daysInCurrentMonth()
                        Text {
                            width: (parent.width - 24) / 7
                            height: 24
                            text: index + 1
                            color: index + 1 === root.now.getDate() ? Theme.colAccent : Theme.colFgDim
                            font.family: Theme.fontFamily
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: index + 1 === root.now.getDate()
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.calendarVisible = false
            }
        }
    }

    function daysInCurrentMonth() {
        return new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    }
}
