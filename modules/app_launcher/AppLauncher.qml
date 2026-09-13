// modules/app_launcher/AppLauncher.qml

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import qs.config

PanelWindow {
    id: root
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Wayland layer configuration
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

    // Cached UI scale and derived metrics. Keeping these in one place avoids
    // repeatedly resolving the same configuration bindings throughout the tree.
    readonly property real uiScale: Config.uiScale
    readonly property int itemH: (AppLauncherConfig.iconSize + (AppLauncherConfig.padY * 2)) * uiScale
    readonly property int launcherW: AppLauncherConfig.width * uiScale
    readonly property int launcherH: AppLauncherConfig.height * uiScale
    readonly property int radiusScaled: AppLauncherConfig.radius * uiScale
    readonly property int scaledPadX: AppLauncherConfig.padX * uiScale
    readonly property int scaledPadY: AppLauncherConfig.padY * uiScale
    readonly property int scaledFontSize: AppLauncherConfig.fontSize * uiScale
    readonly property int scaledIconSize: AppLauncherConfig.iconSize * uiScale

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
    Rectangle {
        id: appLauncherUI
        width: root.launcherW
        height: root.launcherH
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        color: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, Theme.backgroundOpacity)
        topLeftRadius: root.radiusScaled + 10
        topRightRadius: root.radiusScaled + 10
        bottomLeftRadius: 0
        bottomRightRadius: 0
        border.color: Qt.alpha(Theme.colFg, 0.2)
        border.width: 2

        // Intercept clicks inside launcher container
        MouseArea {
            anchors.fill: parent
            onClicked: settingsPopup.open = false
        }

        // Slide up/down animation
        transform: Translate {
            y: AppLauncherState.isVisible ? 0 : root.launcherH + (6 * root.uiScale)
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }

        Column {
            anchors {
                fill: parent
                topMargin: 16 * root.uiScale
                leftMargin: 16 * root.uiScale
                rightMargin: 16 * root.uiScale
                bottomMargin: 0
            }
            spacing: 8 * root.uiScale

            // Header with wallpaper and search
            ClippingRectangle {
                id: header
                width: parent.width
                height: 180 * root.uiScale
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

                    // Circle cutout matching settings button position
                    Rectangle {
                        x: settingsBtn.x
                        y: settingsBtn.y
                        width: settingsBtn.width
                        height: settingsBtn.height
                        radius: width / 2
                        color: "black"
                    }
                }

                // Wallpaper renderer with inverted mask for cog wheel cutout
                MultiEffect {
                    id: maskedWallpaper
                    anchors.fill: wallpaper
                    source: wallpaper
                    maskEnabled: true
                    maskSource: headerCutoutMask
                    maskInverted: true
                    visible: AppLauncherState.isVisible
                }

                // Settings button with adaptive contrast color
                Item {
                    id: settingsBtn
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 12 * root.uiScale
                    }
                    width: 32 * root.uiScale
                    height: 32 * root.uiScale
                    z: 10

                    property color dynamicColor: "#ffffff"

                    // Calculate wallpaper luminance under cog icon to select black or white
                    function updateContrastColor() {
                        if (header.width <= 0 || header.height <= 0) return
                        wallpaper.grabToImage(function(result) {
                                let px = Math.min(Math.max(0, settingsBtn.x + settingsBtn.width / 2), result.image.width - 1)
                                let py = Math.min(Math.max(0, settingsBtn.y + settingsBtn.height / 2), result.image.height - 1)
                                let c = result.image.pixelColor(px, py)
                                let lum = (0.299 * c.r) + (0.587 * c.g) + (0.114 * c.b)
                                settingsBtn.dynamicColor = lum > 0.5 ? "#000000" : "#ffffff"
                            }, Qt.size(header.width, header.height))
                    }

                    Connections {
                        target: AppLauncherState
                        function onIsVisibleChanged() {
                            if (AppLauncherState.isVisible) {
                                settingsBtn.updateContrastColor()
                            }
                        }
                    }

                    Connections {
                        target: wallpaper
                        function onStatusChanged() {
                            if (wallpaper.status === Image.Ready && AppLauncherState.isVisible) {
                                settingsBtn.updateContrastColor()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf013"
                        color: settingsMouse.containsMouse || settingsPopup.open
                        ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 1.0)
                        : settingsBtn.dynamicColor
                        font {
                            pixelSize: 20 * root.uiScale
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
                        topMargin: 4 * root.uiScale
                        right: settingsBtn.right
                    }
                    width: 130 * root.uiScale
                    height: 36 * root.uiScale
                    radius: 8 * root.uiScale
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
                        anchors.margins: 4 * root.uiScale
                        radius: 6 * root.uiScale
                        color: clearMouse.containsMouse
                        ? Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.1)
                        : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Clear recent"
                            color: Qt.rgba(Theme.colFg.r, Theme.colFg.g, Theme.colFg.b, 0.9)
                            font {
                                pixelSize: 12 * root.uiScale
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
                        margins: 12 * root.uiScale
                    }

                    height: 44 * root.uiScale
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

                        spacing: 10 * root.uiScale

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
                width: 36 * root.uiScale
                height: 4 * root.uiScale
                radius: 2 * root.uiScale
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
                    width: 16 * root.uiScale
                    padding: 0
                    leftPadding: 10 * root.uiScale

                    background: Rectangle {
                        anchors.right: parent.right
                        width: 6 * root.uiScale
                        color: Qt.rgba(Theme.colFg.r, Theme.colFg.g, Theme.colFg.b, 0.05)
                        radius: 3 * root.uiScale
                    }

                    contentItem: Rectangle {
                        implicitWidth: 6 * root.uiScale
                        implicitHeight: 30 * root.uiScale
                        radius: 3 * root.uiScale
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

                            spacing: 12 * root.uiScale

                            // App icon container
                            Rectangle {
                                width: root.scaledIconSize
                                height: root.scaledIconSize
                                radius: Math.max(0, root.radiusScaled - (2 * root.uiScale))
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
                                        pixelSize: (AppLauncherConfig.fontSize + 2) * root.uiScale
                                        family: Theme.fontFamily
                                        weight: Font.Bold
                                    }

                                    color: appRow.sel ? Theme.colAccent : Theme.colFg
                                }
                            }

                            // App details
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2 * root.uiScale

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
                                    spacing: 6 * root.uiScale
                                    visible: appRow.isRecent || appRow.app.genericName !== ""

                                    // Recent label badge
                                    Rectangle {
                                        visible: appRow.isRecent
                                        width: recentLabel.width + (8 * root.uiScale)
                                        height: (AppLauncherConfig.fontSize + 2) * root.uiScale
                                        radius: 4 * root.uiScale
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
                                                    9 * root.uiScale,
                                                    (AppLauncherConfig.fontSize - 4) * root.uiScale
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
                                                10 * root.uiScale,
                                                (AppLauncherConfig.fontSize - 2) * root.uiScale
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
