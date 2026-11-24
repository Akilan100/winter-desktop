import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property int snowmanIndex
    required property var snowmanData

    signal closeRequested()

    property string activeTab: "clothes" // "hat", "face", "body", "clothes"

    readonly property var tabOptions: ({
        hat: [
            { id: "none", label: "None" },
            { id: "tophat", label: "Top hat" },
            { id: "bobble", label: "Bobble hat" },
            { id: "santa", label: "Santa hat" },
            { id: "crown", label: "Crown" },
            { id: "cowboy", label: "Cowboy" },
            { id: "party", label: "Party hat" },
            { id: "earmuffs", label: "Earmuffs" }
        ],
        face: [
            { id: "classic", label: "Classic" },
            { id: "happy", label: "Happy" },
            { id: "wink", label: "Wink" },
            { id: "cool", label: "Cool" },
            { id: "surprised", label: "Surprised" },
            { id: "sleepy", label: "Sleepy" },
            { id: "grumpy", label: "Grumpy" },
            { id: "love", label: "In love" }
        ],
        body: [
            { id: "sticks", label: "Sticks" },
            { id: "waving", label: "Waving" },
            { id: "mittens", label: "Mittens" },
            { id: "broom", label: "Broom" },
            { id: "candycane", label: "Candy cane" },
            { id: "cocoa", label: "Cocoa" },
            { id: "gift", label: "Gift" },
            { id: "flowers", label: "Flowers" }
        ],
        clothes: [
            { id: "scarf", label: "Scarf" },
            { id: "striped_scarf", label: "Striped scarf" },
            { id: "bowtie", label: "Bow tie" },
            { id: "tie", label: "Tie" },
            { id: "sweater", label: "Sweater" },
            { id: "puffer", label: "Puffer" },
            { id: "tuxedo", label: "Tuxedo" },
            { id: "gold_chain", label: "Gold chain" }
        ]
    })

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
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Fashion week, but colder."
                color: "#f8fafc"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            // Reset outfit
            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                color: resetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                Text { anchors.centerIn: parent; text: "↺"; color: "#e2e8f0"; font.pixelSize: 14 }
                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.updateSnowman(root.snowmanIndex, {
                        hat: "none", face: "classic", body: "sticks", clothes: "scarf", scale: 1.0
                    })
                }
            }

            // Delete snowman
            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                color: delMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                Text { anchors.centerIn: parent; text: "🗑"; color: "#fca5a5"; font.pixelSize: 12 }
                MouseArea {
                    id: delMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.removeSnowman(root.snowmanIndex)
                }
            }

            // Close card
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

        // Category tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { id: "hat", label: "Hat" },
                    { id: "face", label: "Face" },
                    { id: "body", label: "Body" },
                    { id: "clothes", label: "Clothes" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.activeTab === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 17
                    color: active ? "#3b82f6" : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? "#ffffff" : "#cbd5e1"
                        font.pixelSize: 13
                        font.weight: active ? Font.DemiBold : Font.Medium
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = modelData.id
                    }
                }
            }
        }

        // 4x2 Grid of live Snowman previews
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: root.tabOptions[root.activeTab] || []
                delegate: Rectangle {
                    required property var modelData
                    readonly property string currentVal: root.snowmanData ? (root.snowmanData[root.activeTab] || "") : ""
                    readonly property bool selected: currentVal === modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 106
                    radius: 14
                    color: selected ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : (tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: selected ? 2 : 1
                    border.color: selected ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        SnowmanCanvas {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hat: root.activeTab === "hat" ? modelData.id : (root.snowmanData ? root.snowmanData.hat : "tophat")
                            face: root.activeTab === "face" ? modelData.id : (root.snowmanData ? root.snowmanData.face : "happy")
                            body: root.activeTab === "body" ? modelData.id : (root.snowmanData ? root.snowmanData.body : "mittens")
                            clothes: root.activeTab === "clothes" ? modelData.id : (root.snowmanData ? root.snowmanData.clothes : "scarf")
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: selected ? "#93c5fd" : "#cbd5e1"
                            font.pixelSize: 11
                            font.weight: selected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const patch = {};
                            patch[root.activeTab] = modelData.id;
                            StateStore.updateSnowman(root.snowmanIndex, patch);
                        }
                    }
                }
            }
        }

        // Footer: Size presets + tip
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Size:"
                color: "#94a3b8"
                font.pixelSize: 12
            }

            Repeater {
                model: [
                    { label: "Small", s: 0.75 },
                    { label: "Normal", s: 1.0 },
                    { label: "Big", s: 1.35 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property real curScale: root.snowmanData ? (root.snowmanData.scale || 1.0) : 1.0
                    readonly property bool active: Math.abs(curScale - modelData.s) < 0.1
                    Layout.preferredWidth: szTxt.implicitWidth + 20
                    Layout.preferredHeight: 26
                    radius: 13
                    color: active ? Qt.rgba(0.23, 0.51, 0.96, 0.35) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: active ? "#60a5fa" : "transparent"
                    Text {
                        id: szTxt
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "#e2e8f0"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.updateSnowman(root.snowmanIndex, { scale: modelData.s })
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Drag onto any window top"
                color: "#64748b"
                font.pixelSize: 11
            }
        }
    }
}
