pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "music"

// Музыкальный виджет: карусель CD-дисков, Navidrome + mpv.
// PlayerState живёт всегда (в Scope), окно — только пока открыто.
// Играет mpv в отдельном процессе, так что закрытие окна музыку не трогает.
Scope {
    id: root
    property bool open: false

    PlayerState { id: mp }

    IpcHandler {
        target: "music"
        function toggle(): void { root.open = !root.open }
        function close(): void { root.open = false }
        function activate(): void { root.open = true }
        // для XF86Audio* — работают и без открытого окна
        function playPause(): void { mp.togglePause() }
        function next(): void { mp.next() }
        function previous(): void { mp.previous() }
    }

    FontLoader { id: orbitron; source: Qt.resolvedUrl("../fonts/Orbitron.ttf") }
    FontLoader { id: rajdhani; source: Qt.resolvedUrl("../fonts/Rajdhani-Medium.ttf") }
    FontLoader { source: Qt.resolvedUrl("../fonts/Rajdhani-SemiBold.ttf") }

    LazyLoader {
        active: root.open

        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: true
            exclusionMode: ExclusionMode.Ignore

            // клик по фону закрывает
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 780
                height: 470
                radius: 24
                color: "#1e1e2e"
                border.color: "#3a3a4e"
                border.width: 1

                focus: true
                Keys.onEscapePressed: root.open = false
                Keys.onSpacePressed: mp.togglePause()
                Keys.onLeftPressed: mp.previous()
                Keys.onRightPressed: mp.next()
                Keys.onUpPressed: mp.setVolume(mp.volume + 5)
                Keys.onDownPressed: mp.setVolume(mp.volume - 5)

                // появление: лёгкий zoom + fade
                opacity: 0
                scale: 0.96
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                // съедаем клик по самой карточке
                MouseArea {
                    anchors.fill: parent
                    onClicked: sourceMenu.visible = false
                }

                TrackInfo {
                    x: 32
                    y: 26
                    width: sourceButton.x - x - 24
                    player: mp
                    titleFont: orbitron.name
                    bodyFont: rajdhani.name
                }

                CoverCarousel {
                    x: 0
                    y: 96
                    width: parent.width
                    height: 250
                    player: mp
                }

                SeekBar {
                    x: 32
                    width: parent.width - 64
                    anchors.bottom: arrows.top
                    anchors.bottomMargin: 10
                    player: mp
                    bodyFont: rajdhani.name
                }

                NavArrows {
                    id: arrows
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    player: mp
                }

                VolumeSlider {
                    anchors.right: parent.right
                    anchors.rightMargin: 32
                    anchors.verticalCenter: arrows.verticalCenter
                    player: mp
                }

                // выбор плейлиста
                Rectangle {
                    id: sourceButton
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    y: 26
                    width: Math.min(220, sourceLabel.implicitWidth + 44)
                    height: 32
                    radius: height / 2
                    color: sourceArea.containsMouse ? "#2a2a3a" : "transparent"
                    border.color: "#3a3a4e"
                    border.width: 1

                    Text {
                        id: sourceLabel
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: mp.sourceName || "—"
                        color: "#cccccc"
                        font.family: rajdhani.name
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌄"
                        color: "#cccccc"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: sourceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: sourceMenu.visible = !sourceMenu.visible
                    }
                }

                Rectangle {
                    id: sourceMenu
                    visible: false
                    z: 10
                    anchors.right: sourceButton.right
                    anchors.top: sourceButton.bottom
                    anchors.topMargin: 6
                    width: 240
                    height: Math.min(260, sourceList.contentHeight + 12)
                    radius: 14
                    color: "#1e1e2e"
                    border.color: "#3a3a4e"
                    border.width: 1

                    ListView {
                        id: sourceList
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        spacing: 2
                        model: mp.sources
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: sourceItem
                            required property var modelData
                            width: sourceList.width
                            height: 36
                            radius: 10
                            color: sourceItem.modelData.id === mp.sourceId
                                ? "#7c8cff"
                                : (itemArea.containsMouse ? "#2a2a3a" : "transparent")
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: Text.AlignVCenter
                                text: sourceItem.modelData.name
                                color: "white"
                                font.family: rajdhani.name
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    sourceMenu.visible = false
                                    mp.playSource(sourceItem.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
