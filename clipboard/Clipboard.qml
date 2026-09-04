// Clipboard.qml
// Instructions for AI: preserve comments
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config

Variants {
    model: Quickshell.screens
    PanelWindow {
        id: root
        required property var modelData
        screen: modelData

        visible: ClipboardState.activeScreen === modelData
        implicitWidth: Config.clipboardWidth
        implicitHeight: Config.clipboardHeight

        WlrLayershell.namespace: "quickshell-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            left: true
        }

        // Calculated radius derived from Config
        readonly property real innerRadius: Math.max(2, Config.clipboardRadius - Config.clipboardPadX)
        readonly property real buttonRadius: Math.max(2, root.innerRadius - 4)

        // Cached color palette to prevent constant re-evaluations
        readonly property color cAccent: Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 1.0)
        readonly property color cAccentFill: Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 0.18)
        readonly property color cAccentHover: Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 0.3)
        readonly property color cAccentBorder: Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 0.5)
        readonly property color cAccentScroll: Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 0.7)
        readonly property color cBg: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, Config.bgOpacity)
        readonly property color cFg: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 1.0)
        readonly property color cFgDim: Qt.rgba(Colors.colFgDim.r, Colors.colFgDim.g, Colors.colFgDim.b, 1.0)
        readonly property color cWhiteDim: Qt.rgba(Colors.colWhite.r, Colors.colWhite.g, Colors.colWhite.b, 0.1)
        readonly property color cWhiteHover: Qt.rgba(Colors.colWhite.r, Colors.colWhite.g, Colors.colWhite.b, 0.22)
        readonly property color cWhiteBg: Qt.rgba(Colors.colWhite.r, Colors.colWhite.g, Colors.colWhite.b, 0.04)
        readonly property color cScrollBg: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.05)
        readonly property color cTransparent: "transparent"
        readonly property color cRedHover: Qt.rgba(232/255, 17/255, 35/255, 1.0)
        readonly property color cRedBg: Qt.rgba(56/255, 30/255, 30/255, 1.0)
        readonly property color cCloseHover: Qt.rgba(196/255, 43/255, 28/255, 1.0)

        // Center the window under the cursor, then clamp to this screen's
        // own local bounds so it never gets cut off — same symmetric logic
        // on both axes. `modelData` IS this window's screen, so no lookup
        // is needed here; ClipboardState resolved the target screen once.
        margins {
            left: {
                let localX = ClipboardState.cursorX - modelData.x;
                let offset = -120;
                let maxLeft = modelData.width - root.implicitWidth - 10;
                return Math.max(10, Math.min(localX - root.implicitWidth - offset, maxLeft));
            }

            //formula gave by AI - i dont know how it works , but it works...
            top: {
                let localY = ClipboardState.cursorY - modelData.y;
                let offset = -360;
                let maxTop = modelData.height - root.implicitHeight - 10;
                return Math.max(10, Math.min(localY - root.implicitHeight - offset, maxTop));
            }
        }

        color: root.cTransparent

        Shortcut {
            sequence: "Escape"
            enabled: root.visible
            onActivated: ClipboardState.hide()
        }

        HyprlandFocusGrab {
            active: root.visible
            windows: [ root ]
            onCleared: ClipboardState.hide()
        }

        Rectangle {
            anchors.fill: parent
            color: root.cBg
            radius: Config.clipboardRadius
            border.color: root.cWhiteDim
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.clipboardPadX
                spacing: Config.clipboardItemSpacing

                // Drag handle
                Rectangle {
                    width: 36
                    height: 4
                    radius: 2
                    Layout.alignment: Qt.AlignHCenter
                    color: root.cWhiteHover
                }

                // Header layout
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Clipboard"
                        color: root.cFg
                        font.family: Config.fontFamily
                        font.pixelSize: Config.clipboardHeaderFontSize
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    // Trash icon button triggering clear confirmation
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: root.buttonRadius
                        color: trashArea.containsMouse ? root.cWhiteDim : root.cTransparent

                        Text {
                            anchors.centerIn: parent
                            text: "󰃢"
                            color: trashArea.containsMouse ? root.cAccent : root.cFgDim
                            font.pixelSize: 14
                            font.family: Config.fontFamily
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: trashArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardState.confirmClear = true
                        }
                    }

                    // Window close button
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: root.buttonRadius
                        color: closeArea.containsMouse ? root.cCloseHover : root.cTransparent

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeArea.containsMouse ? root.cFg : root.cFgDim
                            font.pixelSize: 20
                            font.family: Config.fontFamily
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardState.hide()
                        }
                    }
                }

                // Confirmation banner for clearing history
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    visible: ClipboardState.confirmClear
                    color: root.cBg
                    radius: root.innerRadius
                    border.color: root.cAccentHover
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text {
                            text: "Clear all history?"
                            color: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.9)
                            font.family: Config.fontFamily
                            font.pixelSize: 11
                            Layout.fillWidth: true
                        }

                        // Confirm clear button
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 22
                            radius: root.buttonRadius
                            color: yesArea.containsMouse ? root.cRedHover : root.cRedBg

                            Text {
                                anchors.centerIn: parent
                                text: "Clear"
                                color: root.cFg
                                font.family: Config.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: yesArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardState.wipeProc.running = true
                            }
                        }

                        // Cancel clear button
                        Rectangle {
                            implicitWidth: 50
                            implicitHeight: 22
                            radius: root.buttonRadius
                            color: noArea.containsMouse ? root.cWhiteDim : root.cTransparent

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: root.cFgDim
                                font.family: Config.fontFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: noArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardState.confirmClear = false
                            }
                        }
                    }
                }

                // Mode switcher bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ["text", "images", "emojis"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: root.innerRadius
                            color: ClipboardState.currentMode === modelData ? root.cAccentFill : root.cWhiteBg
                            border.color: ClipboardState.currentMode === modelData ? root.cAccentBorder : root.cTransparent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                color: ClipboardState.currentMode === modelData ? root.cFg : root.cFgDim
                                font.family: Config.fontFamily
                                font.pixelSize: 11
                                font.weight: ClipboardState.currentMode === modelData ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardState.currentMode = modelData
                            }
                        }
                    }
                }

                // Search bar input
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    color: Qt.rgba(Colors.colWhite.r, Colors.colWhite.g, Colors.colWhite.b, 0.07)
                    radius: root.innerRadius * 10
                    border.color: searchInput.activeFocus ? Qt.rgba(Colors.colAccent.r, Colors.colAccent.g, Colors.colAccent.b, 0.8) : root.cWhiteDim
                    border.width: 1

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.cFg
                        selectionColor: root.cAccentFill
                        font.family: Config.fontFamily
                        font.pixelSize: Config.clipboardItemFontSize
                        clip: true
                        text: ClipboardState.searchQuery

                        onTextChanged: ClipboardState.searchQuery = text

                        Text {
                            text: ClipboardState.currentMode === "emojis" ? "Search emojis…" : (ClipboardState.currentMode === "images" ? "Search images…" : "Search clipboard…")
                            color: root.cFgDim
                            font.family: Config.fontFamily
                            font.pixelSize: Config.clipboardItemFontSize
                            visible: parent.text.length === 0 && !parent.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Decorative separator line
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.cWhiteDim
                }

                // Images grid view mode
                GridView {
                    id: imageGridView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: ClipboardState.currentMode === "images"
                    clip: true
                    cellWidth: (width - 10) / 2
                    cellHeight: 96
                    model: ClipboardState.clipImageModel

                    ScrollBar.vertical: ScrollBar {
                        id: imgVbar
                        visible: imageGridView.contentHeight > imageGridView.height
                        active: visible
                        width: 16
                        padding: 0
                        leftPadding: 10

                        background: Rectangle {
                            anchors.right: parent.right
                            width: 6
                            color: root.cScrollBg
                            radius: 3
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 30
                            radius: 3
                            color: imgVbar.pressed ? root.cAccent : root.cAccentScroll
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: ClipboardState.clipImageModel.count === 0
                        text: "No images found"
                        color: root.cFgDim
                        font.family: Config.fontFamily
                        font.pixelSize: Config.clipboardItemFontSize
                    }

                    delegate: Rectangle {
                        id: imgCard
                        required property string itemId
                        required property string imagePath

                        implicitWidth: imageGridView.cellWidth - 4
                        implicitHeight: 88
                        radius: root.innerRadius
                        color: imgArea.containsMouse ? root.cAccentFill : root.cWhiteBg
                        border.color: imgArea.containsMouse ? root.cAccentBorder : Qt.rgba(Colors.colWhite.r, Colors.colWhite.g, Colors.colWhite.b, 0.08)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: "file://" + imgCard.imagePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            mipmap: true
                            layer.enabled: true
                        }

                        MouseArea {
                            id: imgArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ClipboardState.hide();
                                ClipboardState.clipboardPasteProc.targetId = itemId;
                                ClipboardState.clipboardPasteProc.running = true;
                            }
                        }
                    }
                }

                // Emojis grid view mode
                GridView {
                    id: emojiGridView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: ClipboardState.currentMode === "emojis"
                    clip: true
                    cellWidth: 44
                    cellHeight: 44
                    model: ClipboardState.emojiModel

                    ScrollBar.vertical: ScrollBar {
                        id: emojiVbar
                        visible: emojiGridView.contentHeight > emojiGridView.height
                        active: visible
                        width: 16
                        padding: 0
                        leftPadding: 10

                        background: Rectangle {
                            anchors.right: parent.right
                            width: 6
                            color: root.cScrollBg
                            radius: 3
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 30
                            radius: 3
                            color: emojiVbar.pressed ? root.cAccent : root.cAccentScroll
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: ClipboardState.emojiModel.count === 0
                        text: ClipboardState.emojiProc.running ? "Loading emojis..." : "No emojis found"
                        color: root.cFgDim
                        font.family: Config.fontFamily
                        font.pixelSize: Config.clipboardItemFontSize
                    }

                    delegate: Rectangle {
                        id: emojiCard
                        required property string emojiChar
                        required property string emojiName

                        implicitWidth: 40
                        implicitHeight: 40
                        radius: root.innerRadius
                        color: emojiArea.containsMouse ? root.cAccentFill : root.cTransparent
                        border.color: emojiArea.containsMouse ? root.cAccentHover : root.cTransparent
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: emojiCard.emojiChar
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 20
                        }

                        MouseArea {
                            id: emojiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ClipboardState.hide();
                                ClipboardState.typeEmojiProc.targetEmoji = emojiChar;
                                ClipboardState.typeEmojiProc.running = true;
                            }
                        }
                    }
                }

                // Main text history list view
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: ClipboardState.currentMode === "text"
                    clip: true
                    model: ClipboardState.clipModel
                    spacing: Config.clipboardItemSpacing

                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        visible: listView.contentHeight > listView.height
                        active: visible
                        width: 16
                        padding: 0
                        leftPadding: 10

                        background: Rectangle {
                            anchors.right: parent.right
                            width: 6
                            color: root.cScrollBg
                            radius: 3
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 30
                            radius: 3
                            color: vbar.pressed ? root.cAccent : root.cAccentScroll
                        }
                    }

                    // Empty state text
                    Text {
                        anchors.centerIn: parent
                        visible: listView.count === 0
                        text: "No history found"
                        color: root.cFgDim
                        font.family: Config.fontFamily
                        font.pixelSize: Config.clipboardItemFontSize
                    }

                    delegate: Rectangle {
                        id: itemCard
                        required property string itemId
                        required property string itemText

                        implicitWidth: listView.width - vbar.width
                        implicitHeight: Config.clipboardItemHeight
                        radius: 12
                        color: itemArea.containsMouse ? root.cAccentFill : root.cTransparent
                        border.color: itemArea.containsMouse ? root.cAccentHover : root.cTransparent
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: itemCard.itemText
                            color: itemArea.containsMouse ? root.cFg : root.cFgDim
                            font.family: Config.fontFamily
                            font.pixelSize: Config.clipboardItemFontSize
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ClipboardState.hide();
                                ClipboardState.clipboardPasteProc.targetId = itemId;
                                ClipboardState.clipboardPasteProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
