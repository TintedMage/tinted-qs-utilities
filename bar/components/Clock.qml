import qs.config
import QtQuick
import "../"

Text {
    id: timeText
    color: Colors.colFg
    font.family: Config.fontFamily
    font.pixelSize: Config.fontSize

    function updateTime() {
        timeText.text = Qt.formatDateTime(new Date(), "hh:mm AP")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.updateTime()
    }

    Component.onCompleted: updateTime()
}
