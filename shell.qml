// shell.qml

import Quickshell
import QtQuick
import "modules/clipboard"
import "modules/app_launcher"

ShellRoot {
    AppLauncher {}
    Clipboard {}
}
