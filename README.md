# Tinted Quickshell Utilities

A small Linux desktop shell built with Quickshell.

## Project Layout

```text
shell.qml                               Starts the shell
core/config/                            Shared colors and settings
modules/main_bar/                       Main bar
modules/main_bar/shaders/                Main bar frame shader
modules/main_bar/widgets/               Bar widgets
modules/clipboard/                      Clipboard window
core/assets/                            Shared images and media
```

## Main Bar

The bar position is set in `modules/main_bar/MainBarSettings.qml`:

```qml
readonly property int barPosition: 0 // 0 = top, 1 = bottom
```

Widgets are placed in three lists:

```qml
readonly property var leftWidgets: ["workspaces"]
readonly property var centerWidgets: ["clock-calendar"]
readonly property var rightWidgets: ["app-launcher"]
```

## Adding A Widget

1. Create a folder in `modules/main_bar/widgets/`.
2. Add the widget QML file.
3. Add settings or state files if needed.
4. Add the widget to the folder's `qmldir` file.
5. Import the folder in `modules/main_bar/MainBar.qml`.
6. Add the widget name to a bar list in `MainBarSettings.qml`.
7. Add its `Component` and `Loader` in `MainBar.qml`.

For a popup widget, keep the button in the bar and create the popup in its own `PanelWindow`. The widget state should control whether the popup is open and how it moves. Keep the popup's position and size in sync with the matching rectangle sent to the frame shader.

## App Launcher

The app launcher button is added by `MainBar.qml`. The launcher window is defined in `modules/main_bar/widgets/app_launcher/AppLauncher.qml`, which also creates one window for each screen.

The launcher can run without the main bar. Its fallback background is set in `AppLauncherSettings.qml`:

```qml
readonly property color fallbackBackgroundColor: "transparent"
```

## Theme

Shared colors, opacity, radius, and frame border settings live in `core/config/Theme.qml`. Use `Theme.radius` for main surfaces instead of adding another global radius value.

## Frame Shader

`modules/main_bar/shaders/Border.frag` draws the frame and the launcher connection. The matching `ShaderEffect` is in `modules/main_bar/MainBar.qml`.

When changing shader inputs, update both files. Keep the radius fixed while a popup moves. Animate its rectangle instead. This keeps the corners steady.

After editing the shader, rebuild it:

```sh
qsb --qt6 -o modules/main_bar/shaders/Border.frag.qsb modules/main_bar/shaders/Border.frag
```

## Folder Imports

Imported folders contain a `qmldir` file. The file lists the QML types and shared settings provided by that folder. Keep the existing folder imports unless Quickshell reports an import error.

## Checks

Run these commands from the project folder:

```sh
qmllint $(find . -name '*.qml' -not -path './.venv/*')
qsb --qt6 -o modules/main_bar/shaders/Border.frag.qsb modules/main_bar/shaders/Border.frag
quickshell --path .
```
