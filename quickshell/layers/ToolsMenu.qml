pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Меню-лаунчер утилит: Super+T открывает, дальше буква запускает нужный
// инструмент (Notes/Projects) через IPC и закрывает само меню.
Scope {
    id: root
    property bool menuVisible: false
    property bool windowActive: false

    onMenuVisibleChanged: {
        if (menuVisible) root.windowActive = true
    }

    IpcHandler {
        target: "toolsmenu"
        function toggle(): void { root.menuVisible = !root.menuVisible }
        function close(): void { root.menuVisible = false }
    }

    function launch(target) {
        Quickshell.execDetached(["quickshell", "ipc", "call", target, "activate"])
        root.menuVisible = false
    }

    LazyLoader {
        active: root.windowActive

        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: true
            exclusionMode: ExclusionMode.Ignore

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
                width: column.implicitWidth + 48
                height: column.implicitHeight + 40
                radius: 24
                color: "#1e1e2e"
                border.color: "#3a3a4e"
                border.width: 1
                clip: true
                focus: true

                Keys.onPressed: (event) => {
                    switch (event.key) {
                        case Qt.Key_N: root.launch("notes"); break
                        case Qt.Key_P: root.launch("projects"); break
                        case Qt.Key_Escape: root.menuVisible = false; break
                    }
                }

                Behavior on x {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: card.open = true

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

                MouseArea { anchors.fill: parent }

                Column {
                    id: column
                    anchors.centerIn: parent
                    spacing: 22

                    Row {
                        spacing: 16
                        Text {
                            width: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "n"
                            color: "#666666"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                        }
                        PowerButton {
                            icon: "📝"; label: "Заметки"; tint: "#27ae60"
                            onClicked: root.launch("notes")
                        }
                    }
                    Row {
                        spacing: 16
                        Text {
                            width: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "p"
                            color: "#666666"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                        }
                        PowerButton {
                            icon: "📁"; label: "Проекты"; tint: "#2980b9"
                            onClicked: root.launch("projects")
                        }
                    }
                }
            }
        }
    }
}
