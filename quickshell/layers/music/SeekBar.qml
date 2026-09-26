import QtQuick

// Прогресс трека с перетаскиванием. Пока тянем — показываем позицию под
// пальцем, а seek в mpv шлём только на отпускание.
Item {
    id: bar
    required property PlayerState player
    required property string bodyFont

    implicitHeight: 36

    readonly property real duration: player.duration > 0 ? player.duration : (player.currentTrack?.duration ?? 0)
    property real dragValue: 0
    readonly property real shown: dragArea.pressed ? dragValue : player.position
    readonly property real fraction: duration > 0 ? Math.max(0, Math.min(1, shown / duration)) : 0

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        y: 6
        height: 4
        radius: 2
        color: "#3a3a4e"

        Rectangle {
            width: bar.fraction * parent.width
            height: parent.height
            radius: 2
            color: "#7c8cff"
        }
        Rectangle {
            x: bar.fraction * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: dragArea.pressed || dragArea.containsMouse ? 14 : 10
            height: width
            radius: width / 2
            color: "white"
            border.color: "#7c8cff"
            border.width: 2
            Behavior on width { NumberAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: dragArea
        anchors.left: parent.left
        anchors.right: parent.right
        y: track.y - 8
        height: track.height + 16
        hoverEnabled: true
        enabled: bar.duration > 0
        function valueAt(x) { return Math.max(0, Math.min(1, x / width)) * bar.duration }
        onPressed: mouse => bar.dragValue = valueAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) bar.dragValue = valueAt(mouse.x) }
        onReleased: bar.player.seek(bar.dragValue)
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: bar.fmt(bar.shown)
        color: "#888aa8"
        font.family: bar.bodyFont
        font.pixelSize: 15
    }
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: bar.fmt(bar.duration)
        color: "#888aa8"
        font.family: bar.bodyFont
        font.pixelSize: 15
    }
}
