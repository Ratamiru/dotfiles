pragma ComponentBehavior: Bound
import QtQuick

// prev / play-pause / next
Row {
    id: nav
    required property PlayerState player

    spacing: 18

    component NavButton: Rectangle {
        id: btn
        property string glyph
        property int glyphSize: 20
        signal activated()
        anchors.verticalCenter: parent?.verticalCenter
        width: 44
        height: 44
        radius: width / 2
        color: area.pressed ? "#3a3a5a" : (area.containsMouse ? "#2a2a3a" : "transparent")
        border.color: "#3a3a4e"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: "white"
            font.family: "Symbols Nerd Font"
            font.pixelSize: btn.glyphSize
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.activated()
        }
    }

    NavButton {
        glyph: "\u{f04ae}"
        onActivated: nav.player.previous()
    }
    NavButton {
        width: 56
        height: 56
        glyph: nav.player.playing ? "\u{f03e4}" : "\u{f040a}"
        glyphSize: 26
        color: "#7c8cff"
        border.width: 0
        onActivated: nav.player.togglePause()
    }
    NavButton {
        glyph: "\u{f04ad}"
        onActivated: nav.player.next()
    }
}
