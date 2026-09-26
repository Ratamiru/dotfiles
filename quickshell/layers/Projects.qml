pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Список проектов: ~/.config/quickshell/projects.json, формат
// [{ "name": "...", "path": "..." }, ...] — редактируется руками.
// Клик по проекту открывает терминал (foot) в его директории.
// Окно persistent: закрывается только явно, не по клику мимо.
Scope {
    id: root
    property bool open: false
    property var projects: []

    IpcHandler {
        target: "projects"
        function toggle(): void { root.open = !root.open }
        function close(): void { root.open = false }
        function activate(): void { root.open = true }
    }

    // true после первой удачной загрузки или первой попытки создать дефолт —
    // защищает от того, чтобы транзиентный FileNotFound (например, во время
    // атомарного сохранения nvim: запись во временный файл + rename поверх
    // старого) не затёр реальный файл дефолтным примером.
    property bool everInitialized: false

    FileView {
        id: projectsFile
        path: Qt.resolvedUrl(Quickshell.shellDir + "/projects.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.everInitialized = true
            try {
                root.projects = JSON.parse(projectsFile.text())
            } catch (e) {
                // не трогаем файл — просто не обновляем список, пока не почините JSON
            }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound && !root.everInitialized) {
                root.everInitialized = true
                const example = [{ "name": "quickshell", "path": Quickshell.env("HOME") + "/.config/quickshell" }]
                projectsFile.setText(JSON.stringify(example, null, 2))
                root.projects = example
            }
        }
    }

    function openProject(path) {
        Quickshell.execDetached(["foot", "-D", path])
        root.open = false
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: true
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 420
                height: Math.min(500, headerRow.height + list.contentHeight + 56)
                radius: 20
                color: "#1e1e2e"
                border.color: "#3a3a4e"
                border.width: 1
                clip: true

                Keys.onEscapePressed: root.open = false

                MouseArea { anchors.fill: parent }

                Item {
                    id: headerRow
                    x: 20
                    y: 16
                    width: parent.width - 40
                    height: 24

                    Text {
                        text: "Проекты"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        anchors.right: parent.right
                        text: "×"
                        color: "#888888"
                        font.pixelSize: 20
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: root.open = false
                        }
                    }
                }

                ListView {
                    id: list
                    anchors.top: headerRow.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    clip: true
                    spacing: 4
                    model: root.projects
                    focus: true
                    currentIndex: root.projects.length > 0 ? 0 : -1
                    keyNavigationEnabled: true

                    Keys.onReturnPressed: list.activateCurrent()
                    Keys.onEnterPressed: list.activateCurrent()
                    function activateCurrent() {
                        if (currentIndex >= 0 && currentIndex < root.projects.length) {
                            root.openProject(root.projects[currentIndex].path)
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 52
                        radius: 10
                        color: (delegateRoot.ListView.isCurrentItem || rowMouse.containsMouse) ? "#2a2a3a" : "transparent"

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            spacing: 2
                            Text {
                                text: delegateRoot.modelData.name ?? ""
                                color: "white"
                                font.pixelSize: 14
                            }
                            Text {
                                text: delegateRoot.modelData.path ?? ""
                                color: "#888888"
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                                width: list.width - 24
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.openProject(delegateRoot.modelData.path)
                        }
                    }
                }

                Text {
                    visible: root.projects.length === 0
                    anchors.centerIn: parent
                    text: "Список пуст.\nДобавьте проекты в\nprojects.json"
                    color: "#666666"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
