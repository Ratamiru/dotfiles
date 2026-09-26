import QtQuick

// Кнопка питания + переключатель отложенного выполнения.
// Таймер живёт снаружи (в Scope, а не в этом окне), поэтому
// закрытие меню не сбрасывает отсчёт.
Row {
    id: root
    property string icon: ""
    property string label: ""
    property color tint: "#2a2a3a"
    property string hotkey: ""
    property Timer timer
    signal triggered()

    spacing: 16

    Text {
        width: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hotkey.length > 0
        text: root.hotkey
        color: "#666666"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
    }

    PowerButton {
        icon: root.icon
        label: root.label
        tint: root.tint
        onClicked: root.triggered()
    }

    ToggleSwitch {
        id: sw
        anchors.verticalCenter: parent.verticalCenter
    }

    Connections {
        target: root.timer
        function onTriggered() { sw.checked = false }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        visible: sw.checked || root.timer.running
        spacing: 6

        Text { text: "schedule"; color: "#888888"; font.pixelSize: 11 }

        Row {
            spacing: 8

            Rectangle {
                width: 56
                height: 30
                radius: 8
                color: "#2a2a3a"
                border.color: "#3a3a4e"
                border.width: 1

                TextInput {
                    id: minutesInput
                    anchors.fill: parent
                    anchors.margins: 4
                    text: "15"
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    validator: IntValidator { bottom: 1; top: 999 }
                    selectByMouse: true
                    enabled: !root.timer.running
                }
            }

            Rectangle {
                width: 56
                height: 30
                radius: 8
                color: root.timer.running ? root.tint : "#2a2a3a"

                Text {
                    anchors.centerIn: parent
                    text: root.timer.running ? "отмена" : "set"
                    color: "white"
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.timer.running) {
                            root.timer.stop()
                        } else {
                            const mins = Math.max(1, parseInt(minutesInput.text) || 15)
                            root.timer.interval = mins * 60000
                            root.timer.restart()
                        }
                    }
                }
            }
        }
    }
}
