pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    property bool menuVisible: false
    // окно живёт немного дольше, чем menuVisible, чтобы доиграть анимацию выезда
    property bool windowActive: false

    onMenuVisibleChanged: {
        if (menuVisible) root.windowActive = true
        // при закрытии windowActive сбросит сама карточка, когда доедет до края
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.menuVisible = !root.menuVisible }
        function close(): void { root.menuVisible = false }
    }

    // Таймеры отложенного выполнения живут здесь, а не в окне —
    // LazyLoader уничтожает окно при закрытии меню, и таймер внутри него пропал бы.
    Timer {
        id: poweroffTimer
        repeat: false
        onTriggered: Quickshell.execDetached(["sudo", "-n", "poweroff"])
    }
    Timer {
        id: rebootTimer
        repeat: false
        onTriggered: Quickshell.execDetached(["sudo", "-n", "reboot"])
    }
    Timer {
        id: sleepTimer
        repeat: false
        onTriggered: Quickshell.execDetached(["sudo", "-n", "zzz"])
    }
    Timer {
        id: logoutTimer
        repeat: false
        onTriggered: Quickshell.execDetached(["pkill", "-TERM", "-x", "mango"])
    }

    LazyLoader {
        active: root.windowActive

        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: true
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
                        case Qt.Key_1: actionPoweroff.triggered(); break
                        case Qt.Key_2: actionReboot.triggered(); break
                        case Qt.Key_3: actionSleep.triggered(); break
                        case Qt.Key_4: actionLogout.triggered(); break
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
                    // окно доехало обратно за левый край — теперь можно уничтожать
                    if (!open && x === closedX && !root.menuVisible) root.windowActive = false
                }

                // съедаем клик по самой карточке, чтобы не закрывалась
                MouseArea { anchors.fill: parent }

                Column {
                    id: column
                    anchors.centerIn: parent
                    spacing: 22

                    PowerAction {
                        id: actionPoweroff
                        icon: "⏻"; label: "Выключить"; tint: "#e74c3c"; hotkey: "1"
                        timer: poweroffTimer
                        onTriggered: {
                            root.menuVisible = false
                            Quickshell.execDetached(["sudo", "-n", "poweroff"])
                        }
                    }
                    PowerAction {
                        id: actionReboot
                        icon: "⟳"; label: "Перезагрузить"; tint: "#f39c12"; hotkey: "2"
                        timer: rebootTimer
                        onTriggered: {
                            root.menuVisible = false
                            Quickshell.execDetached(["sudo", "-n", "reboot"])
                        }
                    }
                    PowerAction {
                        id: actionSleep
                        icon: "⏾"; label: "Сон"; tint: "#3498db"; hotkey: "3"
                        timer: sleepTimer
                        onTriggered: {
                            root.menuVisible = false
                            Quickshell.execDetached(["sudo", "-n", "zzz"])
                        }
                    }
                    PowerAction {
                        id: actionLogout
                        icon: "⎋"; label: "Выйти"; tint: "#9b59b6"; hotkey: "4"
                        timer: logoutTimer
                        onTriggered: {
                            root.menuVisible = false
                            Quickshell.execDetached(["pkill", "-TERM", "-x", "mango"])
                        }
                    }
                }
            }
        }
    }
}
