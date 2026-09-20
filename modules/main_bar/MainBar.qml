// modules/main_bar/MainBar.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.config
import "widgets/app_launcher"
import "widgets/clock_calendar"

PanelWindow {
    id: root

    // This full-screen window owns the frame surface and shader. It does not
    // reserve layout space; the exclusion windows below do that explicitly.

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    color: "transparent"

    // Convert the logical bar position into the full-screen window coordinate.
    readonly property real barY: MainBarSettings.barPosition === 0 ? 0 : height - MainBarSettings.barThickness

    Variants {
        // One transparent reservation window is created per screen edge.
        model: MainBarSettings.exclusionZones

        PanelWindow {
            required property var modelData

            screen: root.screen
            anchors {
                top: modelData.edge === "top"
                bottom: modelData.edge === "bottom"
                left: modelData.edge === "left"
                right: modelData.edge === "right"
            }
            exclusiveZone: modelData.zone
            implicitWidth: 1
            implicitHeight: 1
            mask: Region {}
            color: "transparent"
            WlrLayershell.namespace: "quickshell-main-bar-exclusion"
        }
    }

    mask: Region {
        // Keep the desktop click-through. Only visible frame and widget areas
        // participate in input handling.
        Region { item: leftFrameHitArea }
        Region { item: rightFrameHitArea }
        Region { item: oppositeFrameHitArea }
        Region { item: barHitArea }
        Region { item: widgetLayer }
    }

    // shader
    Item {
        id: surface
        anchors.fill: parent

        ShaderEffect {
            anchors.fill: parent

            // Border.frag owns shape generation. QML supplies geometry, state,
            // and fill color so the shader remains independent of widget types.
            property color backgroundColor: MainBarSettings.backgroundColor
            property color borderColor: MainBarSettings.borderColor
            property vector2d size: Qt.vector2d(width, height)
            property real barThickness: MainBarSettings.barThickness
            property real borderThickness: MainBarSettings.frameThickness
            property real radius: MainBarSettings.cornerRadius
            property real smoothing: MainBarSettings.curveSmoothing
            property real borderWidth: MainBarSettings.borderWidth
            property int barPosition: MainBarSettings.barPosition
            property vector4d launcher: Qt.vector4d(
                (width - AppLauncherState.launcherWidth) / 2,
                height - AppLauncherState.launcherHeight * AppLauncherState.reveal,
                AppLauncherState.launcherWidth,
                AppLauncherState.launcherHeight
            )
            property real launcherRadius: AppLauncherState.cornerRadius
            fragmentShader: Qt.resolvedUrl("shaders/Border.frag.qsb")
        }

        // Transparent rectangles mirror the visible frame for Wayland hit testing.
        Rectangle {
            id: leftFrameHitArea
            x: 0
            y: MainBarSettings.barPosition === 0
            ? MainBarSettings.barThickness
            : 0
            width: MainBarSettings.frameThickness
            height: parent.height - MainBarSettings.barThickness
            color: "transparent"
        }

        Rectangle {
            id: rightFrameHitArea
            x: parent.width - MainBarSettings.frameThickness
            y: MainBarSettings.barPosition === 0
            ? MainBarSettings.barThickness
            : 0
            width: MainBarSettings.frameThickness
            height: parent.height - MainBarSettings.barThickness
            color: "transparent"
        }

        Rectangle {
            id: oppositeFrameHitArea
            x: MainBarSettings.frameThickness
            y: MainBarSettings.barPosition === 0
            ? parent.height - MainBarSettings.frameThickness
            : 0
            width: parent.width - (2 * MainBarSettings.frameThickness)
            height: MainBarSettings.frameThickness
            color: "transparent"
        }

        Rectangle {
            id: barHitArea
            x: 0
            y: root.barY
            width: parent.width
            height: MainBarSettings.barThickness
            color: "transparent"
        }

        Item {
            id: widgetLayer
            x: 0
            y: root.barY
            width: parent.width
            height: MainBarSettings.barThickness
            z: 2

            // Each zone is independently repeatable. Add a widget identifier to
            // MainBarSettings and map it to a Component below to extend the bar.

            Row {
                id: leftWidgets
                anchors.left: parent.left
                anchors.leftMargin: MainBarSettings.widgetMargin
                height: parent.height
                spacing: MainBarSettings.widgetSpacing

                Repeater {
                    model: MainBarSettings.leftWidgets
                    Loader {
                        height: leftWidgets.height
                        sourceComponent: modelData === "workspaces"
                        ? workspacesComponent
                        : null
                    }
                }
            }

            Row {
                id: centerWidgets
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height
                spacing: MainBarSettings.widgetSpacing

                Repeater {
                    model: MainBarSettings.centerWidgets
                    Loader {
                        height: centerWidgets.height
                        sourceComponent: modelData === "clock-calendar"
                        ? clockComponent
                        : null
                    }
                }
            }

            Row {
                id: rightWidgets
                anchors.right: parent.right
                anchors.rightMargin: MainBarSettings.widgetMargin
                height: parent.height
                spacing: MainBarSettings.widgetSpacing

                Repeater {
                    model: MainBarSettings.rightWidgets
                    Loader {
                        height: rightWidgets.height
                        sourceComponent: modelData === "app-launcher"
                        ? launcherComponent
                        : null
                    }
                }
            }
        }
    }

    // position of widgets on the bar
    Component {
        id: workspacesComponent

        // Connected widget: content stays inside the bar surface.

        Item {
            implicitWidth: 140
            implicitHeight: MainBarSettings.barThickness

            Text {
                anchors.centerIn: parent
                color: Theme.colFg
                text: "1  2  3  4  5"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }
    }

    Component {
        id: clockComponent

        // Connected widget with its own detached popup window.

        ClockCalendar {
            panelScreen: root.screen
            barPosition: MainBarSettings.barPosition
            barThickness: MainBarSettings.barThickness
        }
    }

    Component {
        id: launcherComponent

        // The trigger stays in the bar; AppLauncher.qml owns the full-screen
        // overlay and AppLauncherState owns its visibility and geometry state.

        Item {
            implicitWidth: 110
            implicitHeight: MainBarSettings.barThickness

            Text {
                anchors.centerIn: parent
                color: Theme.colFg
                text: "Apps"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: AppLauncherState.toggle()
            }
        }
    }

}
