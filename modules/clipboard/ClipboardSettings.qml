// modules/clipboard/ClipboardSettings.qml

pragma Singleton
import QtQuick
import qs.core.config

QtObject {
    // Clipboard layout

    readonly property int width: 360
    readonly property int height: 480
    readonly property real radius: Theme.radius
    readonly property real outerBorderWidth: 1
    readonly property color outerBorderColor: Qt.rgba(
        Theme.colWhite.r,
        Theme.colWhite.g,
        Theme.colWhite.b,
        0.22
    )

    readonly property int padX: 20
    readonly property int padY: 20

    readonly property int itemHeight: 50
    readonly property int itemSpacing: 10
    readonly property int headerFontSize: 16
    readonly property int itemFontSize: 11
    readonly property int imageCellHeight: 96
    readonly property int imageItemHeight: 88

    readonly property real backgroundOpacity: 0.8


    // Clipboard history limits

    readonly property int maxItems: 50
    readonly property int maxImageItems: 10

    // Popup positioning

    readonly property real xOffset: -120
    readonly property real yOffset: -360

    // Process timing

    readonly property real pasteDelay: 0.15
    readonly property real emojiDelay: 0.15

    // Image cache

    readonly property string imageCacheDir: "/tmp/qs_clip_img"
}
