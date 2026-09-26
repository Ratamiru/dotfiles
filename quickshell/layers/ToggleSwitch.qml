import QtQuick

Rectangle {
    id: root
    property bool checked: false
    signal toggled()

    width: 40
    height: 22
    radius: height / 2
    color: checked ? "#2ecc71" : "#3a3a4e"
    border.color: "#1e1e2e"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: parent.height - 4
        height: parent.height - 4
        radius: width / 2
        color: "white"
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
}
