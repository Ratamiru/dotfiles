pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects

// Экран блокировки на ext-session-lock-v1. Настоящая блокировка сессии,
// а не просто окно поверх всего — если этот процесс умрёт, компоситор
// оставит экран запертым (так и задумано протоколом, это и есть защита).
Scope {
    id: root

    property string password: ""
    property string statusMessage: ""
    property bool statusIsError: false
    property bool unlocking: false
    property string wallpaperPath: ""

    // Берём актуальные обои из конфига waypaper, а не захардкоженный путь —
    // так фон блокировки не разъедется с тем, что реально стоит на столе.
    FileView {
        id: waypaperConfig
        path: Qt.resolvedUrl((Quickshell.env("HOME") ?? "") + "/.config/waypaper/config.ini")
        onLoaded: {
            const match = waypaperConfig.text().match(/^wallpaper\s*=\s*(.+)$/m)
            if (match) root.wallpaperPath = match[1].trim()
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            root.password = ""
            root.statusMessage = ""
            root.statusIsError = false
            sessionLock.locked = true
        }
    }

    PamContext {
        id: pam
        config: "swaylock"

        onResponseRequiredChanged: {
            if (responseRequired) pam.respond(root.password)
        }

        onCompleted: (result) => {
            root.unlocking = false
            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                root.statusMessage = "Неверный пароль"
                root.statusIsError = true
            }
            root.password = ""
        }

        onError: (err) => {
            root.unlocking = false
            root.statusMessage = "Ошибка авторизации"
            root.statusIsError = true
            root.password = ""
        }
    }

    function submit() {
        if (root.unlocking || root.password.length === 0) return
        root.unlocking = true
        root.statusMessage = ""
        root.statusIsError = false
        pam.start()
    }

    WlSessionLock {
        id: sessionLock
        // Автолок на старте убран — за вход теперь отвечает SDDM,
        // дублировать его тут не нужно. Обычный toggle через IPC
        // (Super+Shift+L, хук sleep) остаётся как есть.

        surface: Component {
            WlSessionLockSurface {
                id: surf
                color: "black"

                Image {
                    id: capture
                    anchors.fill: parent
                    source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: capture
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    saturation: -0.2
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#50000000"
                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.26
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "hh:mm")
                        color: "white"
                        font.pixelSize: 76
                        font.weight: Font.Light
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(clock.date, "dddd, d MMMM")
                        color: "#cccccc"
                        font.pixelSize: 18
                    }
                }

                Rectangle {
                    id: passField
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.56
                    width: 280
                    height: 46
                    radius: 23
                    color: "#301e1e2e"
                    border.color: root.statusIsError ? "#e74c3c" : "#4a4a5e"
                    border.width: 1

                    Text {
                        visible: pwInput.text.length === 0
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Пароль"
                        color: "#888888"
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        verticalAlignment: TextInput.AlignVCenter
                        color: "white"
                        font.pixelSize: 16
                        echoMode: TextInput.Password
                        enabled: !root.unlocking
                        focus: true
                        text: root.password
                        onTextChanged: root.password = text
                        onAccepted: root.submit()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: passField.bottom
                    anchors.topMargin: 12
                    text: root.unlocking ? "Проверка…" : root.statusMessage
                    color: root.statusIsError ? "#e74c3c" : "#888888"
                    font.pixelSize: 13
                }

                Component.onCompleted: pwInput.forceActiveFocus()
            }
        }
    }
}
