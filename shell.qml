// Shell.qml

import Quickshell
import "modules/app_launcher"
import "modules/clipboard"
import "modules/panels"

ShellRoot {
    Variants {
        model: Quickshell.screens
        AppLauncher {
            required property var modelData
            screen: modelData
        }
    }

    Clipboard {}

    PanelBorder {}
    TopCornerCurves {}
    BottomCornerCurves {}
}
