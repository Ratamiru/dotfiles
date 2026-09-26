import QtQuick

// Название трека крупно (Orbitron), под ним исполнитель (Rajdhani)
Column {
    id: info
    required property PlayerState player
    required property string titleFont
    required property string bodyFont

    spacing: 2

    Text {
        width: info.width
        text: info.player.currentTrack?.title
            ?? (info.player.loading ? "ЗАГРУЗКА…" : (info.player.errorText || "НЕТ ТРЕКОВ"))
        color: "white"
        font.family: info.titleFont
        font.pixelSize: 26
        font.weight: Font.Bold
        font.letterSpacing: 1
        elide: Text.ElideRight
    }
    Text {
        width: info.width
        text: info.player.currentTrack?.artist ?? ""
        color: "#a8acd8"
        font.family: info.bodyFont
        font.pixelSize: 19
        font.weight: Font.Medium
        elide: Text.ElideRight
    }
}
