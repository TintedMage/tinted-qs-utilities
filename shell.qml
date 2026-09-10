// Shell.qml

import Quickshell
import "modules/app_launcher"

ShellRoot {
    Variants {
        model: Quickshell.screens
        AppLauncher {
            required property var modelData
            screen: modelData
        }
    }
}
