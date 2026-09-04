import Quickshell
import Quickshell.Io
import "bar"
import "app_launcher"
import "clipboard"

ShellRoot {
    // BottomBar {}

    Variants {
        model: Quickshell.screens
        AppLauncher {
            required property var modelData
            screen: modelData
        }
    }

    Border{}
    Clipboard {}
}
