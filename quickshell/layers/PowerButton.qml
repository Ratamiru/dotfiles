import QtQuick
Column {
	id: root
	property string icon: ""
  property string label: ""
  property color tint: "#2a2a3a"
  signal clicked()

  spacing: 6
  Rectangle{
    width: 64
    height: 64
    radius: 32
    color: mouseArea.containsMouse ? Qt.lighter(root.tint, 1.2) : root.tint
    Text {
      anchors.centerIn: parent
      text: root.icon
      font.pixelSize: 28
      color: "white"
    }
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.clicked()
    }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.label
    color: '#cccccc'
    font.pixelSize: 12
  }
}

