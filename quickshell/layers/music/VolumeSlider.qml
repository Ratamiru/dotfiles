import QtQuick

// Громкость mpv (не системная). Клик по иконке — mute, колесо — ±5%.
Row {
    id: vol
    required property PlayerState player

    spacing: 10
    enabled: player.mpvConnected
    opacity: enabled ? 1 : 0.4

    // пока тянем — показываем значение под курсором, не дожидаясь ответа mpv
    property real dragValue: 0
    readonly property real shown: area.pressed ? dragValue : player.volume
    readonly property real fraction: player.muted ? 0 : shown / 100

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        text: vol.player.muted || vol.shown === 0 ? "\u{f0581}"
            : vol.shown < 34 ? "\u{f057f}"
            : vol.shown < 67 ? "\u{f0580}" : "\u{f057e}"
        color: iconArea.containsMouse ? "white" : "#cccccc"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 20
        MouseArea {
            id: iconArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: vol.player.toggleMute()
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 110
        height: 24

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: "#3a3a4e"

            Rectangle {
                width: vol.fraction * parent.width
                height: parent.height
                radius: 2
                color: "#7c8cff"
            }
            Rectangle {
                x: vol.fraction * parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: area.pressed || area.containsMouse ? 14 : 10
                height: width
                radius: width / 2
                color: "white"
                border.color: "#7c8cff"
                border.width: 2
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            function valueAt(x) { return Math.max(0, Math.min(1, x / width)) * 100 }
            onPressed: mouse => {
                vol.dragValue = valueAt(mouse.x)
                vol.player.setVolume(vol.dragValue)
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                vol.dragValue = valueAt(mouse.x)
                vol.player.setVolume(vol.dragValue)
            }
            onWheel: wheel => vol.player.setVolume(vol.player.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        text: Math.round(vol.player.muted ? 0 : vol.shown) + "%"
        color: "#888aa8"
        font.family: "Rajdhani"
        font.pixelSize: 15
    }
}
