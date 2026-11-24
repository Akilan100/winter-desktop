import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property int treeIndex
    required property var treeData

    signal closeRequested()

    readonly property var sizeNames: ["Bonsai", "Shrub", "Tree", "Big", "Giant"]
    readonly property var topperList: [
        { id: "star", label: "Star" },
        { id: "snowflake", label: "Snowflake" },
        { id: "bow", label: "Bow" },
        { id: "bell", label: "Bell" },
        { id: "heart", label: "Heart" },
        { id: "spire", label: "Spire" }
    ]
    readonly property var ornamentList: [
        { id: "baubles", label: "Baubles" },
        { id: "lights", label: "Lights" },
        { id: "garland", label: "Garland" },
        { id: "candy_canes", label: "Candy canes" },
        { id: "bells", label: "Bells" },
        { id: "gingerbread", label: "Gingerbread" },
        { id: "bows", label: "Bows" },
        { id: "stars", label: "Stars" }
    ]

    function hasOrnament(id) {
        const list = treeData && treeData.ornaments ? treeData.ornaments : [];
        return list.indexOf(id) !== -1;
    }

    function toggleOrnament(id) {
        const list = (treeData && treeData.ornaments ? treeData.ornaments : []).slice();
        const idx = list.indexOf(id);
        if (idx === -1) list.push(id);
        else list.splice(idx, 1);
        StateStore.updateTree(root.treeIndex, { ornaments: list });
    }

    function surpriseMe() {
        const toppers = ["star", "snowflake", "bow", "bell", "heart", "spire"];
        const allOrns = ["baubles", "lights", "garland", "candy_canes", "bells", "gingerbread", "bows", "stars"];
        const picked = [];
        for (let i = 0; i < allOrns.length; i++) {
            if (Math.random() > 0.42) picked.push(allOrns[i]);
        }
        if (picked.length === 0) picked.push("baubles", "lights");
        StateStore.updateTree(root.treeIndex, {
            topper: toppers[Math.floor(Math.random() * toppers.length)],
            ornaments: picked
        });
    }

    width: 420
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Deck the tree."
                color: "#f8fafc"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: surpTxt.implicitWidth + 22
                Layout.preferredHeight: 30
                radius: 15
                color: surpMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.35) : Qt.rgba(1, 1, 1, 0.09)
                Text { id: surpTxt; anchors.centerIn: parent; text: "✨ Surprise me"; color: "#e0f2fe"; font.pixelSize: 12 }
                MouseArea {
                    id: surpMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.surpriseMe()
                }
            }

            Rectangle {
                Layout.preferredWidth: chopTxt.implicitWidth + 20
                Layout.preferredHeight: 30
                radius: 15
                color: chopMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                Text { id: chopTxt; anchors.centerIn: parent; text: "Chop down"; color: "#fca5a5"; font.pixelSize: 12 }
                MouseArea {
                    id: chopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.removeTree(root.treeIndex)
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

        // Size selector
        Text { text: "Size"; color: "#94a3b8"; font.pixelSize: 12; font.weight: Font.Medium }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.sizeNames
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool active: (root.treeData ? root.treeData.sizeLevel : 2) === index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 16
                    color: active ? "#22c55e" : Qt.rgba(1, 1, 1, 0.07)
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: active ? "#052e16" : "#cbd5e1"
                        font.pixelSize: 12
                        font.weight: active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.updateTree(root.treeIndex, { sizeLevel: index })
                    }
                }
            }
        }

        // Topper selector
        Text { text: "On top"; color: "#94a3b8"; font.pixelSize: 12; font.weight: Font.Medium }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6
            Repeater {
                model: root.topperList
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: (root.treeData ? root.treeData.topper : "star") === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 12
                    color: active ? Qt.rgba(0.98, 0.80, 0.08, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: active ? 1.5 : 1
                    border.color: active ? "#facc15" : Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? "#fef08a" : "#cbd5e1"
                        font.pixelSize: 12
                        font.weight: active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.updateTree(root.treeIndex, { topper: modelData.id })
                    }
                }
            }
        }

        // Ornaments multi-toggle
        Text { text: "Ornaments"; color: "#94a3b8"; font.pixelSize: 12; font.weight: Font.Medium }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6
            Repeater {
                model: root.ornamentList
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.hasOrnament(modelData.id)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 12
                    color: active ? Qt.rgba(0.23, 0.51, 0.96, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: active ? 1.5 : 1
                    border.color: active ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? "#93c5fd" : "#cbd5e1"
                        font.pixelSize: 11
                        font.weight: active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleOrnament(modelData.id)
                    }
                }
            }
        }
    }
}
