// modules/main_bar/widgets/app_launcher/AppLauncher.qml

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import qs.core.config

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Wayland layer configuration
        // Must stay full-screen and line up pixel-for-pixel with the panel window that draws the
        // launcher's shape, so ignore the exclusive zones of the bar/border windows.
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: AppLauncherState.isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-launcher"

        // Handle IPC commands for launcher visibility
        IpcHandler {
            target: "applauncher"
            function toggle() { AppLauncherState.toggle() }
            function show() { AppLauncherState.show() }
            function hide() { AppLauncherState.hide() }
        }

        // Input mask allows click passthrough when hidden
        mask: Region {
            item: AppLauncherState.isVisible ? maskCover : null
        }

        Item {
            id: maskCover
            anchors.fill: parent
        }

        // UI state
        property int selectedIndex: 0

        // Cached derived metrics used throughout the launcher.
        readonly property int itemH: (AppLauncherSettings.iconSize + (AppLauncherSettings.padY * 2))
        readonly property real launcherW: AppLauncherState.launcherWidth
        readonly property real launcherH: AppLauncherState.launcherHeight
        readonly property int radiusScaled: AppLauncherSettings.radius
        readonly property int scaledPadX: AppLauncherSettings.padX
        readonly property int scaledPadY: AppLauncherSettings.padY
        readonly property int scaledFontSize: AppLauncherSettings.fontSize
        readonly property int scaledIconSize: AppLauncherSettings.iconSize

        // Cached theme colors used frequently by delegates/effects.
        readonly property color accentFill: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.18)
        readonly property color accentIcon: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28)
        readonly property color white07: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.07)
        readonly property color white08: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.08)
        readonly property color white22: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.22)

        // Launch selected application
        function launchSelected() {
            const model = AppLauncherState.currentModel
            const count = model.length

            if (count === 0)
            return

            const index = Math.max(0, Math.min(selectedIndex, count - 1))
            const entry = model[index]

            if (entry)
            AppLauncherState.launch(entry.id)
        }

        // Navigate through list
        function navigate(delta) {
            const count = AppLauncherState.currentModel.length

            if (count === 0)
            return

            const nextIndex = Math.max(0, Math.min(selectedIndex + delta, count - 1))

            if (nextIndex === selectedIndex)
            return

            selectedIndex = nextIndex
            listView.positionViewAtIndex(nextIndex, ListView.Contain)
        }

        // Reset UI state when data or visibility changes
        Connections {
            target: AppLauncherState

            function onCurrentModelChanged() {
                root.selectedIndex = 0
            }

            function onIsVisibleChanged() {
                if (AppLauncherState.isVisible) {
                    root.selectedIndex = 0
                    listView.positionViewAtIndex(0, ListView.Beginning)
                    searchInput.forceActiveFocus()
                } else {
                    settingsPopup.open = false
                }
            }
        }

        // Close launcher when clicking outside the launcher
        MouseArea {
            anchors.fill: parent
            enabled: AppLauncherState.isVisible
            onClicked: AppLauncherState.hide()
        }

        // Main launcher
        // Content only. The background (fill, rounded top corners, and the curved joins into the
        // bottom border) is drawn by the main bar shader.
        Item {
            id: appLauncherUI
            width: root.launcherW
            height: root.launcherH
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            // Intercept clicks inside launcher container
            MouseArea {
                anchors.fill: parent
                onClicked: settingsPopup.open = false
            }

            // Slide up/down: driven by the same value the panel uses for the shape
            transform: Translate {
                y: (1 - AppLauncherState.reveal) * root.launcherH
            }

            // Optional fallback surface for running the launcher without MainBar.
            // Keep transparent to let the main bar shader draw the launcher shape.
            Rectangle {
                id: fallbackSurface
                anchors.fill: parent
                color: AppLauncherSettings.fallbackBackgroundColor
                radius: root.radiusScaled
                z: -1
            }

            Column {
                anchors {
                    fill: parent
                    topMargin: 16
                    leftMargin: 16
                    rightMargin: 16
                    bottomMargin: AppLauncherSettings.bottomMargin
                }
                spacing: 8

                // Header with wallpaper and search
                ClippingRectangle {
                    id: header
                    width: parent.width
                    height: 180
                    radius: root.radiusScaled
                    color: root.white07

                    // Close settings popup when cursor leaves wallpaper header area
                    HoverHandler {
                        id: headerHover
                        onHoveredChanged: {
                            if (!hovered) settingsPopup.open = false
                        }
                    }

                    // Source wallpaper image
                    Image {
                        id: wallpaper
                        anchors.fill: parent
                        source: Config.currentWallpaper
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.8
                        visible: false
                    }

                    // Mask defining cutout areas for compositor transparency
                    Item {
                        id: headerCutoutMask
                        anchors.fill: parent
                        visible: false
                    }

                    // Wallpaper renderer
                    MultiEffect {
                        id: maskedWallpaper
                        anchors.fill: wallpaper
                        source: wallpaper
                        visible: AppLauncherState.isVisible
                    }

                    // Settings button
                    Item {
                        id: settingsBtn
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 12
                        }
                        width: 32
                        height: 32
                        z: 10

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013"
                            color: "#ad000000"
                            font {
                                pixelSize: 20
                                family: Theme.fontFamily
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsPopup.open = !settingsPopup.open
                        }
                    }

                    // Settings popup menu
                    Rectangle {
                        id: settingsPopup
                        property bool open: false

                        anchors {
                            top: settingsBtn.bottom
                            topMargin: 4
                            right: settingsBtn.right
                        }
                        width: 130
                        height: 36
                        radius: 8
                        z: 100
                        color: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, 0.95)
                        border.color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.3)
                        border.width: 1

                        opacity: open ? 1.0 : 0.0
                        visible: opacity > 0
                        scale: open ? 1.0 : 0.95

                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 6
                            color: clearMouse.containsMouse
                            ? Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.1)
                            : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "Clear recent"
                                color: Qt.rgba(Theme.colFg.r, Theme.colFg.g, Theme.colFg.b, 0.9)
                                font {
                                    pixelSize: 12
                                    family: Theme.fontFamily
                                }
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    AppLauncherState.clearRecents()
                                    settingsPopup.open = false
                                }
                            }
                        }
                    }

                    // Search bar container
                    ClippingRectangle {
                        id: searchBar
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            margins: 12
                        }

                        height: 44
                        radius: 30
                        color: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.8)
                        border.color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.9)
                        border.width: 1

                        // Downsampled texture capture for low-overhead QML blur
                        ShaderEffectSource {
                            id: searchBarBlurSource
                            sourceItem: wallpaper

                            sourceRect: Qt.rect(
                                searchBar.x,
                                searchBar.y,
                                searchBar.width,
                                searchBar.height
                            )

                            width: searchBar.width
                            height: searchBar.height

                            // 4x downscaling reduces GPU fill rate computation by 16x
                            textureSize: Qt.size(
                                Math.ceil(searchBar.width / 4),
                                Math.ceil(searchBar.height / 4)
                            )
                            hideSource: false
                            live: AppLauncherState.isVisible
                        }

                        // Low-cost Gaussian blur on downsampled source
                        MultiEffect {
                            id: searchBarBlur

                            anchors.fill: parent
                            source: searchBarBlurSource

                            blurEnabled: true
                            blurMax: 50
                            blur: 1

                            autoPaddingEnabled: false
                            visible: AppLauncherState.isVisible
                        }

                        // Search input layout
                        Row {
                            anchors {
                                fill: parent
                                leftMargin: root.scaledPadX
                                rightMargin: root.scaledPadX
                            }

                            spacing: 10

                            Item {
                                width: parent.width
                                height: parent.height

                                Text {
                                    anchors.fill: parent
                                    text: AppLauncherState.isSearching ? "" : "Search apps…"
                                    color: Theme.colWhite

                                    font {
                                        pixelSize: root.scaledFontSize
                                        family: Theme.fontFamily
                                    }

                                    verticalAlignment: Text.AlignVCenter
                                    visible: searchInput.text === ""
                                }

                                TextInput {
                                    id: searchInput

                                    anchors.fill: parent
                                    color: Theme.colFg
                                    selectionColor: root.accentFill

                                    font {
                                        pixelSize: root.scaledFontSize
                                        family: Theme.fontFamily
                                    }

                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: AppLauncherState.searchQuery

                                    onTextChanged: AppLauncherState.searchQuery = text

                                    Keys.onPressed: function (event) {
                                        if (event.key === Qt.Key_Up) {
                                            root.navigate(-1)
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Down) {
                                            root.navigate(1)
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.launchSelected()
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Escape) {
                                            AppLauncherState.hide()
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Drag handle / decorative separator
                Rectangle {
                    width: 36
                    height: 4
                    radius: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.white22
                }

                // Application list
                ListView {
                    id: listView
                    width: parent.width
                    height: parent.height - y
                    model: AppLauncherState.currentModel
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        active: true
                        width: 16
                        padding: 0
                        leftPadding: 10

                        background: Rectangle {
                            anchors.right: parent.right
                            width: 6
                            color: Qt.rgba(Theme.colFg.r, Theme.colFg.g, Theme.colFg.b, 0.05)
                            radius: 3
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 30
                            radius: 3
                            color: vbar.pressed ? Theme.colAccent : Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.7)
                        }
                    }

                    // Empty search state
                    Text {
                        anchors.centerIn: parent
                        visible: listView.count === 0
                        text: "No apps found"
                        color: Theme.colFgDim

                        font {
                            pixelSize: root.scaledFontSize
                            family: Theme.fontFamily
                        }
                    }

                    // App item delegate
                    delegate: Item {
                        id: appRow
                        width: listView.width - vbar.width
                        height: root.itemH

                        required property var modelData
                        required property int index

                        readonly property var app: modelData
                        readonly property bool sel: root.selectedIndex === index
                        readonly property bool isRecent: !AppLauncherState.isSearching && AppLauncherState.recentIds.indexOf(app.id) !== -1

                        Rectangle {
                            anchors.fill: parent
                            radius: root.radiusScaled
                            color: appRow.sel ? root.accentFill : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: root.scaledPadX
                                    rightMargin: root.scaledPadX
                                }

                                spacing: 12

                                // App icon container
                                Rectangle {
                                    width: root.scaledIconSize
                                    height: root.scaledIconSize
                                    radius: Math.max(0, root.radiusScaled - (2))
                                    anchors.verticalCenter: parent.verticalCenter

                                    color: appIcon.status === Image.Ready
                                    ? "transparent"
                                    : (appRow.sel
                                        ? root.accentIcon
                                        : Qt.rgba(
                                            Theme.colWhite.r,
                                            Theme.colWhite.g,
                                            Theme.colWhite.b,
                                            0.08
                                    ))

                                    Behavior on color {
                                        ColorAnimation { duration: 100 }
                                    }

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: root.scaledIconSize * 0.65
                                        height: root.scaledIconSize * 0.65
                                        source: appRow.app.icon !== "" ? Quickshell.iconPath(appRow.app.icon, true) : ""
                                        smooth: true
                                        mipmap: true
                                        visible: status === Image.Ready
                                    }

                                    // Fallback text if icon fails to load
                                    Text {
                                        anchors.centerIn: parent
                                        visible: appIcon.status !== Image.Ready
                                        text: appRow.app.name.charAt(0).toUpperCase()

                                        font {
                                            pixelSize: (AppLauncherSettings.fontSize + 2)
                                            family: Theme.fontFamily
                                            weight: Font.Bold
                                        }

                                        color: appRow.sel ? Theme.colAccent : Theme.colFg
                                    }
                                }

                                // App details
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: appRow.app.name

                                        font {
                                            pixelSize: root.scaledFontSize
                                            family: Theme.fontFamily
                                            weight: appRow.sel ? Font.Medium : Font.Normal
                                        }

                                        color: appRow.sel ? Theme.colFg : Theme.colFgDim
                                    }

                                    Row {
                                        spacing: 6
                                        visible: appRow.isRecent || appRow.app.genericName !== ""

                                        // Recent label badge
                                        Rectangle {
                                            visible: appRow.isRecent
                                            width: recentLabel.width + (8)
                                            height: (AppLauncherSettings.fontSize + 2)
                                            radius: 4
                                            color: Qt.rgba(
                                                Theme.colAccent.r,
                                                Theme.colAccent.g,
                                                Theme.colAccent.b,
                                                0.22
                                            )

                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                id: recentLabel
                                                anchors.centerIn: parent
                                                text: "recent"

                                                font {
                                                    pixelSize: Math.max(
                                                        9,
                                                        (AppLauncherSettings.fontSize - 4)
                                                    )
                                                    family: Theme.fontFamily
                                                }

                                                color: Theme.colAccent
                                            }
                                        }

                                        // App generic name (description)
                                        Text {
                                            visible: appRow.app.genericName !== ""
                                            text: appRow.app.genericName

                                            font {
                                                pixelSize: Math.max(
                                                    10,
                                                    (AppLauncherSettings.fontSize - 2)
                                                )
                                                family: Theme.fontFamily
                                            }

                                            color: Theme.colFgDim
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            // Mouse interactions for app item
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = appRow.index
                                onClicked: AppLauncherState.launch(appRow.app.id)

                                onWheel: function (wheel) {
                                    if (wheel.angleDelta.y < 0)
                                    root.navigate(1)
                                    else
                                    root.navigate(-1)
                                }
                            }
                        }
                    }
                }

            }
        }
    }
}
