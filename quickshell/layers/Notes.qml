pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel

// Окно заметок: список .md файлов из настраиваемой папки + редактор.
// Persistent: не закрывается само, только по крестику/Escape.
Scope {
    id: root
    property bool open: false
    property string notesDir: (Quickshell.env("HOME") ?? "") + "/notes"
    property string selectedFile: ""
    property bool suppressSave: false

    IpcHandler {
        target: "notes"
        function toggle(): void { root.open = !root.open }
        function close(): void { root.open = false }
        function activate(): void { root.open = true }
    }

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl(Quickshell.shellDir + "/notes-settings.json")
        onLoaded: {
            try {
                const data = JSON.parse(settingsFile.text())
                if (data.dir) root.notesDir = data.dir
            } catch (e) { /* оставляем дефолт */ }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                settingsFile.setText(JSON.stringify({ dir: root.notesDir }))
            }
        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({ dir: root.notesDir }))
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            focusable: true
            exclusionMode: ExclusionMode.Ignore

            FileView {
                id: noteFile
                path: root.selectedFile ? Qt.resolvedUrl(root.notesDir + "/" + root.selectedFile) : ""
                // при создании новой заметки первое чтение всегда "не найдено" —
                // это ожидаемо (см. onLoadFailed ниже), не нужно пугать логом
                printErrors: false
                onLoaded: {
                    root.suppressSave = true
                    editor.text = noteFile.text()
                    root.suppressSave = false
                }
                onLoadFailed: (error) => {
                    root.suppressSave = true
                    editor.text = ""
                    root.suppressSave = false
                    if (error === FileViewError.FileNotFound) {
                        // новый файл — создаём пустым, чтобы появился в списке
                        noteFile.setText("")
                    }
                }
            }

            function saveCurrent() {
                if (root.selectedFile) noteFile.setText(editor.text)
            }

            function openFile(name) {
                saveCurrent()
                root.selectedFile = name
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 840
                height: 560
                radius: 20
                color: "#1e1e2e"
                border.color: "#3a3a4e"
                border.width: 1
                clip: true
                focus: true

                Keys.onEscapePressed: {
                    win.saveCurrent()
                    root.open = false
                }

                // Заголовок: папка + крестик
                Row {
                    id: headerRow
                    x: 20
                    y: 16
                    width: parent.width - 40
                    height: 30
                    spacing: 10

                    Text {
                        text: "Заметки"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 420
                        height: 28
                        radius: 8
                        color: "#2a2a3a"
                        border.color: "#3a3a4e"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        TextInput {
                            id: dirInput
                            anchors.fill: parent
                            anchors.margins: 6
                            text: root.notesDir
                            color: "white"
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onAccepted: {
                                win.saveCurrent()
                                root.notesDir = dirInput.text
                                root.saveSettings()
                                root.selectedFile = ""
                                editor.text = ""
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: headerRow.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    text: "×"
                    color: "#888888"
                    font.pixelSize: 20
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: {
                            win.saveCurrent()
                            root.open = false
                        }
                    }
                }

                // Список файлов слева
                Rectangle {
                    id: sidebar
                    x: 12
                    y: headerRow.y + headerRow.height + 12
                    width: 200
                    height: parent.height - y - 12
                    radius: 10
                    color: "#181822"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Row {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                width: parent.width - 32
                                height: 26
                                radius: 6
                                color: "#2a2a3a"
                                visible: !newNoteRow.visible
                                Text {
                                    anchors.centerIn: parent
                                    text: "Новая заметка"
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: newNoteRow.visible = true
                                }
                            }
                        }

                        Row {
                            id: newNoteRow
                            visible: false
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 26
                                radius: 6
                                color: "#2a2a3a"
                                border.color: "#7c8cff"
                                border.width: 1

                                TextInput {
                                    id: newNoteInput
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    color: "white"
                                    font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    onAccepted: {
                                        let name = newNoteInput.text.trim()
                                        if (name.length > 0) {
                                            if (!name.endsWith(".md")) name += ".md"
                                            win.openFile(name)
                                        }
                                        newNoteInput.text = ""
                                        newNoteRow.visible = false
                                    }
                                    Keys.onEscapePressed: {
                                        newNoteInput.text = ""
                                        newNoteRow.visible = false
                                    }
                                }
                            }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 40
                            clip: true
                            spacing: 2
                            model: FolderListModel {
                                folder: "file://" + root.notesDir
                                nameFilters: ["*.md"]
                                showDirs: false
                                sortField: FolderListModel.Name
                            }

                            delegate: Rectangle {
                                id: fileRow
                                required property string fileName
                                width: ListView.view.width
                                height: 30
                                radius: 6
                                color: fileName === root.selectedFile
                                    ? "#7c8cff"
                                    : (fileMouse.containsMouse ? "#2a2a3a" : "transparent")

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    text: fileRow.fileName
                                    color: "white"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: fileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: win.openFile(fileRow.fileName)
                                }
                            }
                        }
                    }
                }

                // Редактор справа
                Rectangle {
                    x: sidebar.x + sidebar.width + 12
                    y: sidebar.y
                    width: parent.width - x - 12
                    height: sidebar.height
                    radius: 10
                    color: "#181822"

                    Text {
                        visible: root.selectedFile.length === 0
                        anchors.centerIn: parent
                        text: "Выберите файл слева\nили создайте новый"
                        color: "#555555"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: root.selectedFile.length > 0
                        clip: true

                        TextArea {
                            id: editor
                            wrapMode: TextArea.Wrap
                            color: "white"
                            font.pixelSize: 14
                            background: null
                            selectByMouse: true
                            onTextChanged: if (!root.suppressSave) autosaveTimer.restart()
                        }
                    }

                    Timer {
                        id: autosaveTimer
                        interval: 800
                        onTriggered: win.saveCurrent()
                    }
                }
            }
        }
    }
}
