// modules/panels/PanelBorder.qml

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config

Scope {
    id: root

    readonly property int thickness: PanelConfig.thickness
    readonly property color borderColor: PanelConfig.borderColor
    readonly property var wlrlayer: PanelConfig.wlrlayer
    readonly property string namespace: PanelConfig.namespace

    Variants {
        model: Quickshell.screens

        Item {
            id: screenRoot

            required property var modelData

            PanelWindow {
                screen: screenRoot.modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: root.thickness
                exclusiveZone: root.thickness
                WlrLayershell.layer: root.wlrlayer
                WlrLayershell.namespace: root.namespace
                color: root.borderColor
            }

            PanelWindow {
                screen: screenRoot.modelData
                anchors { bottom: true; left: true; right: true }
                implicitHeight: root.thickness
                exclusiveZone: root.thickness
                WlrLayershell.layer: root.wlrlayer
                WlrLayershell.namespace: root.namespace
                color: root.borderColor
            }

            PanelWindow {
                screen: screenRoot.modelData
                anchors { top: true; bottom: true; left: true }
                implicitWidth: root.thickness
                exclusiveZone: root.thickness
                WlrLayershell.layer: root.wlrlayer
                WlrLayershell.namespace: root.namespace
                color: root.borderColor
            }

            PanelWindow {
                screen: screenRoot.modelData
                anchors { top: true; bottom: true; right: true }
                implicitWidth: root.thickness
                exclusiveZone: root.thickness
                WlrLayershell.layer: root.wlrlayer
                WlrLayershell.namespace: root.namespace
                color: root.borderColor
            }
        }
    }
}
