// shell.qml

import Quickshell
import QtQuick
import "modules/clipboard"
import "modules/app_launcher"
import "modules/screen_corners"

ShellRoot {
    AppLauncher {}
    Clipboard {}
    ScreenCorners {}
}
