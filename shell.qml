// shell.qml

import Quickshell
import QtQuick
import "modules/clipboard"
import "modules/main_bar"
import "modules/main_bar/widgets/app_launcher"

ShellRoot {
    AppLauncher {}
    Clipboard {}
    MainBar {}
}
