import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelRoot

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // This window covers the whole screen and draws the frame itself, so it must not be
    // shrunk by (or reserve) any exclusive zone. Space is reserved by the small windows below.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-panel"
    color: "transparent"

    // Caelestia-style exclusion zones: a compositor ignores exclusiveZone on a surface anchored
    // to all four edges, so reserve the bar + border space with tiny invisible per-edge windows.
    Variants {
        model: {
            const p = PanelConfig.panelPosition;
            const t = PanelConfig.panelThickness;
            const b = PanelConfig.borderThickness;
            return [
            { edge: "top",    zone: p === 0 ? t : b },
            { edge: "bottom", zone: p === 1 ? t : b },
            { edge: "left",   zone: b },
            { edge: "right",  zone: b }
            ];
        }

        PanelWindow {
            required property var modelData

            screen: panelRoot.screen
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
            WlrLayershell.namespace: "quickshell-panel-exclusion"
        }
    }

    // Click-through mask adapts automatically to top or bottom position
    mask: Region {
        Region { item: mainBarRect }
        Region { item: leftBorderRect }
        Region { item: rightBorderRect }
        Region { item: oppositeBorderRect }
        Region { item: trayWidget }
    }

    Item {
        id: container
        anchors.fill: parent

        ShaderEffect {
            anchors.fill: parent

            property color fillColor: PanelConfig.fillColor
            property vector2d size: Qt.vector2d(width, height)
            property real panelThickness: PanelConfig.panelThickness
            property real borderThickness: PanelConfig.borderThickness
            property real radius: PanelConfig.radius
            property real smoothing: PanelConfig.smoothing
            property int edgeSide: PanelConfig.panelPosition

            property vector4d w1: Qt.vector4d(workspaces.x, workspaces.y, workspaces.width, workspaces.height)
            property vector4d w2: Qt.vector4d(clockWidget.x, clockWidget.y, clockWidget.width, clockWidget.height)
            property vector4d w3: Qt.vector4d(trayWidget.x, trayWidget.y, trayWidget.width, trayWidget.height)

            fragmentShader: "border.frag.qsb"
        }

        // Dynamic hit-test rectangles for click-through
        Rectangle {
            id: mainBarRect
            x: 0
            y: PanelConfig.panelPosition === 0 ? 0 : container.height - PanelConfig.panelThickness
            width: container.width
            height: PanelConfig.panelThickness
            color: "transparent"
        }
        Rectangle {
            id: leftBorderRect
            x: 0
            y: PanelConfig.panelPosition === 0 ? PanelConfig.panelThickness : 0
            width: PanelConfig.borderThickness
            height: container.height - PanelConfig.panelThickness
            color: "transparent"
        }
        Rectangle {
            id: rightBorderRect
            x: container.width - PanelConfig.borderThickness
            y: PanelConfig.panelPosition === 0 ? PanelConfig.panelThickness : 0
            width: PanelConfig.borderThickness
            height: container.height - PanelConfig.panelThickness
            color: "transparent"
        }
        Rectangle {
            id: oppositeBorderRect
            x: PanelConfig.borderThickness
            y: PanelConfig.panelPosition === 0 ? container.height - PanelConfig.borderThickness : 0
            width: container.width - (2 * PanelConfig.borderThickness)
            height: PanelConfig.borderThickness
            color: "transparent"
        }

        // --- WIDGETS ---
        readonly property real barY: PanelConfig.panelPosition === 0 ? 0 : container.height - PanelConfig.panelThickness

        Rectangle {
            id: workspaces
            x: 24
            y: container.barY
            width: 140
            height: PanelConfig.panelThickness
            color: "transparent"
            z: 2

            Text {
                anchors.centerIn: parent
                color: "white"
                text: "1 2 3 4 5"
                font.bold: true
            }
        }

        Rectangle {
            id: clockWidget
            x: (container.width - width) / 2
            y: container.barY
            width: 120
            height: PanelConfig.panelThickness
            color: "transparent"
            z: 2

            Text {
                anchors.centerIn: parent
                color: "white"
                text: "12:00 pm"
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: calendarPopup.visible = !calendarPopup.visible
            }
        }

        Rectangle {
            id: trayWidget
            x: container.width - width - 24
            y: PanelConfig.panelPosition === 0 ? 0 : container.height - height
            width: 110
            height: expanded ? 110 : PanelConfig.panelThickness
            color: "transparent"
            z: 2
            property bool expanded: false

            Behavior on height {
                NumberAnimation { duration: 350; easing.type: Easing.OutBack }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: trayWidget.expanded = !trayWidget.expanded
            }

            Text {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                text: trayWidget.expanded ? "sys tray\nexpanded" : "Sys Tray"
                font.bold: true
            }
        }
    }

    PanelWindow {
        id: calendarPopup
        visible: false
        screen: panelRoot.screen
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-panel"
        color: "transparent"

        anchors {
            top: PanelConfig.panelPosition === 0
            bottom: PanelConfig.panelPosition === 1
        }
        margins {
            top: PanelConfig.panelPosition === 0 ? PanelConfig.panelThickness + 8 : 0
            bottom: PanelConfig.panelPosition === 1 ? PanelConfig.panelThickness + 8 : 0
        }
        implicitWidth: 300
        implicitHeight: 250

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 12

            Text {
                anchors.centerIn: parent
                color: "white"
                text: "Overlay Popup Window"
            }
        }
    }
}
