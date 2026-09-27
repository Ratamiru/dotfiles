pragma ComponentBehavior: Bound
import QtQuick

// Кнопка-"таблетка" с выпадающим списком: model = [{ id, name }].
// Список рисуется поверх остального (z), закрывается выбором или close().
Item {
    id: pill
    property var model: []
    property string currentId: ""
    property string label: ""
    property string icon: ""
    property string fontFamily: ""
    property int maxWidth: 220
    property int menuWidth: 240
    readonly property bool opened: menu.visible
    signal picked(string id)

    function close() { menu.visible = false }

    width: Math.min(pill.maxWidth, content.implicitWidth + 44)
    height: 32
    z: menu.visible ? 20 : 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: area.containsMouse || menu.visible ? "#2a2a3a" : "transparent"
        border.color: "#3a3a4e"
        border.width: 1
    }

    Row {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            visible: pill.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.icon
            color: "#cccccc"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 14
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, pill.maxWidth - 44 - (pill.icon !== "" ? 20 : 0))
            text: pill.label || "—"
            color: "#cccccc"
            font.family: pill.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
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
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: menu.visible = !menu.visible
    }

    Rectangle {
        id: menu
        visible: false
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.topMargin: 6
        width: pill.menuWidth
        height: Math.min(280, list.contentHeight + 12)
        radius: 14
        color: "#1e1e2e"
        border.color: "#3a3a4e"
        border.width: 1

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            spacing: 2
            model: pill.model
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: item
                required property var modelData
                width: list.width
                height: 36
                radius: 10
                color: item.modelData.id === pill.currentId
                    ? "#7c8cff"
                    : (itemArea.containsMouse ? "#2a2a3a" : "transparent")
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: item.modelData.name
                    color: "white"
                    font.family: pill.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        menu.visible = false
                        pill.picked(item.modelData.id)
                    }
                }
            }
        }
    }
}
