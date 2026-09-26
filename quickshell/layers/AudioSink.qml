pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root
    property bool menuVisible: false
    // окно живёт немного дольше, чем menuVisible, чтобы доиграть анимацию выезда
    property bool windowActive: false

    onMenuVisibleChanged: {
        if (menuVisible) root.windowActive = true
    }

    readonly property real volumeStep: 0.05

    function adjustVolume(delta) {
        const sink = Pipewire.defaultAudioSink;
        if (!sink) return;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
    }

    IpcHandler {
        target: "audiosink"
        function toggle(): void { root.menuVisible = !root.menuVisible }
        function close(): void { root.menuVisible = false }
        // громкость без открытия окна — для XF86Audio*Volume
        function raise(): void { root.adjustVolume(root.volumeStep) }
        function lower(): void { root.adjustVolume(-root.volumeStep) }
        function mute(): void {
            const sink = Pipewire.defaultAudioSink;
            if (sink) sink.audio.muted = !sink.audio.muted;
        }
    }

    LazyLoader {
        active: root.windowActive

        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: false
            exclusionMode: ExclusionMode.Ignore

            // клик по фону закрывает меню
            MouseArea {
                anchors.fill: parent
                onClicked: root.menuVisible = false
            }

            Rectangle {
                id: card
                readonly property real openX: 48
                readonly property real closedX: -width
                property bool open: false

                x: open ? openX : closedX
                y: (parent.height - height) / 2
                width: 320
                height: column.implicitHeight + 48
                radius: 24
                color: "#1e1e2e"
                border.color: "#3a3a4e"
                border.width: 1

                Behavior on x {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }

                Connections {
                    target: root
                    function onMenuVisibleChanged() {
                        // синхронизируем в обе стороны, а не только на закрытие —
                        // иначе быстрый toggle открыть->закрыть->открыть до того,
                        // как окно успело уничтожиться, навсегда роняет card.open
                        // в false: окно остаётся невидимым, но живым и с фокусом
                        card.open = root.menuVisible
                    }
                }

                onXChanged: {
                    if (!open && x === closedX && !root.menuVisible) root.windowActive = false
                }

                // съедаем клик по самой карточке, чтобы не закрывалась
                MouseArea { anchors.fill: parent }

                // Список аудио-синков
                property var sinkNodes: []

                function rebuildSinkNodes() {
                    const nodes = Pipewire.nodes.values;
                    const result = [];
                    for (let i = 0; i < nodes.length; i++) {
                        const n = nodes[i];
                        if (n.isSink && !n.isStream) result.push(n);
                    }
                    card.sinkNodes = result;
                }
                Connections {
                    target: Pipewire.nodes
                    function onValuesChanged() { card.rebuildSinkNodes() }
                }

                Component.onCompleted: {
                    card.open = true
                    card.rebuildSinkNodes()
                }

                PwObjectTracker {
                    objects: card.sinkNodes
                }

                Column {
                    id: column
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 18

                    // "Таблетка" выбора синка
                    ComboBox {
                        id: combo
                        width: parent.width
                        height: 44
                        model: card.sinkNodes
                        textRole: "description"

                        function syncCurrentIndex() {
                            const activeSink = Pipewire.defaultAudioSink;
                            if (!activeSink) return;
                            for (let i = 0; i < card.sinkNodes.length; i++) {
                                if (card.sinkNodes[i].id == activeSink.id) {
                                    combo.currentIndex = i;
                                    return;
                                }
                            }
                        }
                        Component.onCompleted: combo.syncCurrentIndex()
                        Connections {
                            target: Pipewire
                            function onDefaultAudioSinkChanged() { combo.syncCurrentIndex() }
                        }
                        Connections {
                            target: card
                            function onSinkNodesChanged() { combo.syncCurrentIndex() }
                        }
                        onActivated: function(index) {
                            const chosen = card.sinkNodes[index];
                            if (chosen) Pipewire.preferredDefaultAudioSink = chosen;
                        }

                        background: Rectangle {
                            radius: height / 2
                            color: "#2a2a3a"
                            border.color: "#3a3a4e"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: combo.displayText.length ? combo.displayText : "Audio Sink"
                            color: "white"
                            font.pixelSize: 15
                            leftPadding: 18
                            rightPadding: 30
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        indicator: Text {
                            text: "⌄"
                            color: "#cccccc"
                            font.pixelSize: 16
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        popup: Popup {
                            y: combo.height + 6
                            width: combo.width
                            padding: 6
                            implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 220)

                            contentItem: ListView {
                                implicitHeight: contentHeight
                                clip: true
                                model: combo.popup.visible ? combo.delegateModel : null
                                currentIndex: combo.highlightedIndex
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 2
                            }

                            background: Rectangle {
                                color: "#1e1e2e"
                                border.color: "#3a3a4e"
                                border.width: 1
                                radius: 14
                            }
                        }

                        delegate: ItemDelegate {
                            id: delItem
                            required property var modelData
                            required property int index
                            width: combo.width - 12
                            height: 40

                            contentItem: Text {
                                text: delItem.modelData.description
                                color: "white"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                leftPadding: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 10
                                color: combo.highlightedIndex === delItem.index
                                    ? "#7c8cff"
                                    : (delItem.hovered ? "#2a2a3a" : "transparent")
                            }
                        }
                    }

                    // Слайдер громкости + проценты
                    Row {
                        width: parent.width
                        spacing: 12

                        Slider {
                            id: volumeSlider
                            width: parent.width - percentLabel.width - parent.spacing
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            stepSize: 0.01
                            value: Pipewire.defaultAudioSink?.audio.volume ?? 0

                            onMoved: {
                                const sink = Pipewire.defaultAudioSink;
                                if (sink) sink.audio.volume = volumeSlider.value;
                            }

                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#3a3a4e"

                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 2
                                    color: "#7c8cff"
                                }
                            }
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                border.color: "#7c8cff"
                                border.width: 2
                            }
                        }

                        Text {
                            id: percentLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(volumeSlider.value * 100) + "%"
                            color: "#cccccc"
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
