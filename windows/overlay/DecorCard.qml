import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property real screenW
    required property real screenH

    signal closeRequested()

    readonly property var decorCatalog: [
        { kind: "lights", label: "Lights" },
        { kind: "candle", label: "Candle" },
        { kind: "red_bauble", label: "Red bauble" },
        { kind: "gold_bauble", label: "Gold bauble" },
        { kind: "star", label: "Star" },
        { kind: "wreath", label: "Wreath" },
        { kind: "stocking", label: "Stocking" },
        { kind: "candycane", label: "Candy cane" },
        { kind: "gift", label: "Gift" },
        { kind: "bells", label: "Bells" },
        { kind: "gingerbread", label: "Gingerbread" },
        { kind: "holly", label: "Holly" },
        { kind: "santahat", label: "Santa hat" },
        { kind: "snowglobe", label: "Snow globe" },
        { kind: "cocoa", label: "Cocoa" },
        { kind: "boat", label: "Boat" }
    ]

    width: 430
    height: col.implicitHeight + 32
    radius: 22
    color: Qt.rgba(0.08, 0.10, 0.16, 0.92)
    border.color: Qt.rgba(1, 1, 1, 0.16)
    border.width: 1.2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Deck your screen."
                color: "#f8fafc"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: clrTxt.implicitWidth + 20
                Layout.preferredHeight: 30
                radius: 15
                color: clrMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                Text { id: clrTxt; anchors.centerIn: parent; text: "Take all down"; color: "#fca5a5"; font.pixelSize: 12 }
                MouseArea {
                    id: clrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.clearDecors()
                }
            }

            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                Text { anchors.centerIn: parent; text: "✕"; color: "#e2e8f0"; font.pixelSize: 12 }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Text {
            text: "Pick something to place it. Drag to move, scroll to resize."
            color: "#94a3b8"
            font.pixelSize: 11
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: root.decorCatalog
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    radius: 14
                    color: tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: tileMa.containsMouse ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        DecorCanvas {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            kind: modelData.kind
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: "#cbd5e1"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.addDecor(modelData.kind, root.screenW, root.screenH)
                    }
                }
            }
        }

        Text {
            text: StateStore.decors.length + " of 16 up"
            color: "#64748b"
            font.pixelSize: 11
        }
    }
}
