// modules/app_launcher/AppLauncher.qml

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
        // Full-screen overlay so the floating launcher can be dragged anywhere and clicking
        // outside closes it. Ignore the exclusive zones of the bar/border windows.
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
        readonly property color cBg: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, AppLauncherSettings.backgroundOpacity)
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

        // Keeps the launcher fully on screen
        function clampX(v) { return Math.max(0, Math.min(v, root.width - root.launcherW)) }
        function clampY(v) { return Math.max(0, Math.min(v, root.height - root.launcherH)) }

        // Snap the launcher to a screen position. h/v: -1 = left/top, 0 = center, 1 = right/bottom
        function anchorTo(h, v) {
            const m = AppLauncherSettings.anchorMargin
            const x = h < 0 ? m : (h > 0 ? root.width - root.launcherW - m : (root.width - root.launcherW) / 2)
            const y = v < 0 ? m : (v > 0 ? root.height - root.launcherH - m : (root.height - root.launcherH) / 2)
            AppLauncherState.setPosition(root.clampX(x), root.clampY(y))
            AppLauncherState.savePosition()
        }

        // Main launcher (floating window, draws its own background)
        Item {
            id: appLauncherUI
            width: root.launcherW
            height: root.launcherH

            x: root.clampX(AppLauncherState.posX < 0 ? (root.width - width) / 2 : AppLauncherState.posX)
            y: root.clampY(AppLauncherState.posY < 0 ? (root.height - height) / 2 : AppLauncherState.posY)

            visible: AppLauncherState.isVisible

            // Intercept clicks inside launcher container
            MouseArea {
                anchors.fill: parent
                onClicked: settingsPopup.open = false
            }

            // Background surface
            Rectangle {
                id: bgSurface
                anchors.fill: parent
                radius: AppLauncherState.cornerRadius
                color: root.cBg
                border.width: 1
                border.color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.3)
                visible: false
            }

            // Renders the surface with a soft drop shadow so it reads as floating
            MultiEffect {
                anchors.fill: bgSurface
                source: bgSurface
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.55
                shadowBlur: 1.0
                shadowVerticalOffset: 8
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

                    // Drag the launcher by grabbing the header
                    MouseArea {
                        id: headerDrag
                        anchors.fill: parent
                        cursorShape: AppLauncherState.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        acceptedButtons: Qt.LeftButton

                        property real pressX: 0
                        property real pressY: 0

                        onPressed: function (mouse) {
                            pressX = mouse.x
                            pressY = mouse.y
                            AppLauncherState.dragging = true
                            settingsPopup.open = false
                        }

                        onPositionChanged: function (mouse) {
                            if (!pressed) return
                            // The item moves with the cursor, so mouse.x/y are relative to the
                            // moving header: shifting by the delta keeps the grab point fixed.
                            AppLauncherState.setPosition(
                                root.clampX(appLauncherUI.x + mouse.x - pressX),
                                root.clampY(appLauncherUI.y + mouse.y - pressY))
                        }

                        onReleased: {
                            AppLauncherState.dragging = false
                            AppLauncherState.savePosition()
                        }

                        onCanceled: AppLauncherState.dragging = false
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

                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsPopup.open = !settingsPopup.open
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

            // Corner resize handles
            Repeater {
                model: [
                { left: true,  top: true  },
                { left: false, top: true  },
                { left: true,  top: false },
                { left: false, top: false }
                ]

                delegate: MouseArea {
                    id: grip
                    required property var modelData

                    readonly property bool onLeft: modelData.left
                    readonly property bool onTop: modelData.top

                    width: 22
                    height: 22
                    x: onLeft ? 0 : appLauncherUI.width - width
                    y: onTop ? 0 : appLauncherUI.height - height
                    z: 50
                    acceptedButtons: Qt.LeftButton
                    cursorShape: (onLeft === onTop) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

                    property point startScene
                    property real sx: 0
                    property real sy: 0
                    property real sw: 0
                    property real sh: 0

                    onPressed: function (mouse) {
                        startScene = mapToItem(null, mouse.x, mouse.y)
                        sx = appLauncherUI.x
                        sy = appLauncherUI.y
                        sw = appLauncherUI.width
                        sh = appLauncherUI.height
                        AppLauncherState.resizing = true
                        settingsPopup.open = false
                    }

                    onPositionChanged: function (mouse) {
                        if (!pressed) return

                        // Scene coordinates: stable even though the handle moves while resizing
                        const p = mapToItem(null, mouse.x, mouse.y)
                        const dx = p.x - startScene.x
                        const dy = p.y - startScene.y

                        const minW = AppLauncherSettings.minWidth
                        const minH = AppLauncherSettings.minHeight

                        // Width: grow toward the dragged edge, never past the screen
                        const maxW = onLeft ? sx + sw : root.width - sx
                        const maxH = onTop ? sy + sh : root.height - sy

                        const w = Math.max(minW, Math.min(sw + (onLeft ? -dx : dx), Math.max(minW, maxW)))
                        const h = Math.max(minH, Math.min(sh + (onTop ? -dy : dy), Math.max(minH, maxH)))

                        // Dragging a left/top corner keeps the opposite edge anchored
                        const x = onLeft ? sx + sw - w : sx
                        const y = onTop ? sy + sh - h : sy

                        AppLauncherState.setGeometry(x, y, w, h)
                    }

                    onReleased: {
                        AppLauncherState.resizing = false
                        AppLauncherState.saveGeometry()
                    }

                    onCanceled: AppLauncherState.resizing = false
                }
            }

            // Settings popup menu (lives outside the header so it is not clipped)
            Rectangle {
                id: settingsPopup
                property bool open: false

                anchors {
                    top: parent.top
                    topMargin: 64
                    right: parent.right
                    rightMargin: 28
                }
                width: 168
                height: popupCol.implicitHeight + 16
                radius: 10
                z: 100
                color: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, 0.97)
                border.color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.3)
                border.width: 1

                visible: open

                // Swallow clicks on empty popup space
                MouseArea { anchors.fill: parent }

                Column {
                    id: popupCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }
                    spacing: 4

                    Text {
                        text: "Position"
                        color: Theme.colFgDim
                        leftPadding: 4
                        font {
                            pixelSize: 10
                            family: Theme.fontFamily
                        }
                    }

                    // 3x3 anchor grid: corners, edges and center
                    Grid {
                        columns: 3
                        spacing: 4
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: [
                            { h: -1, v: -1, glyph: "\u2196" }, { h: 0, v: -1, glyph: "\u2191" }, { h: 1, v: -1, glyph: "\u2197" },
                            { h: -1, v:  0, glyph: "\u2190" }, { h: 0, v:  0, glyph: "\u25cf" }, { h: 1, v:  0, glyph: "\u2192" },
                            { h: -1, v:  1, glyph: "\u2199" }, { h: 0, v:  1, glyph: "\u2193" }, { h: 1, v:  1, glyph: "\u2198" }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                width: Math.floor((popupCol.width - 8) / 3)
                                height: 28
                                radius: 6
                                color: anchorMouse.containsMouse
                                ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.25)
                                : Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.06)


                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.glyph
                                    color: Theme.colFg
                                    font {
                                        pixelSize: 14
                                        family: Theme.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: anchorMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.anchorTo(parent.modelData.h, parent.modelData.v)
                                        settingsPopup.open = false
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.1)
                    }

                    Repeater {
                        model: [
                        { label: "Reset layout", action: "reset" },
                        { label: "Clear recent", action: "clear" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: popupCol.width
                            height: 28
                            radius: 6
                            color: itemMouse.containsMouse
                            ? Qt.rgba(Theme.colWhite.r, Theme.colWhite.g, Theme.colWhite.b, 0.1)
                            : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: Qt.rgba(Theme.colFg.r, Theme.colFg.g, Theme.colFg.b, 0.9)
                                font {
                                    pixelSize: 12
                                    family: Theme.fontFamily
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.modelData.action === "clear")
                                    AppLauncherState.clearRecents()
                                    else
                                    AppLauncherState.resetPosition()
                                    settingsPopup.open = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
