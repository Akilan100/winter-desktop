import QtQuick

Item {
    id: root

    required property int itemIndex
    required property var itemData
    required property real screenW
    required property real screenH
    required property bool selected

    signal clicked(int idx)
    signal moved(int idx, real nx, real ny)
    signal updated(int idx, var patch)
    signal removed(int idx)

    readonly property string kind: itemData ? (itemData.kind || "star") : "star"
    readonly property real itemScale: itemData ? (itemData.scale || 1.0) : 1.0
    readonly property real itemRot: itemData ? (itemData.rotation || 0) : 0

    width: (kind === "lights" ? 260 : 110) * itemScale
    height: (kind === "lights" ? 70 : 110) * itemScale

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property bool hovered: dragArea.containsMouse || controlsRow.hovered

    x: dragging ? dragX : Math.max(64, Math.min(screenW - width - 8, itemData ? (itemData.x || 200) : 200))
    y: dragging ? dragY : Math.max(12, Math.min(screenH - height - 8, itemData ? (itemData.y || 120) : 120))

    DecorCanvas {
        anchors.fill: parent
        kind: root.kind
        rotation: root.itemRot
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "transparent"
        border.width: root.hovered || root.selected ? 1.5 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real pressX: 0
        property real pressY: 0
        property real startX: 0
        property real startY: 0
        property bool movedEnough: false

        onPressed: mouse => {
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            pressX = pt.x;
            pressY = pt.y;
            startX = root.x;
            startY = root.y;
            root.dragX = root.x;
            root.dragY = root.y;
            movedEnough = false;
            root.dragging = true;
        }

        onPositionChanged: mouse => {
            if (!pressed) return;
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            const dx = pt.x - pressX;
            const dy = pt.y - pressY;
            if (Math.abs(dx) > 4 || Math.abs(dy) > 4) movedEnough = true;
            if (!movedEnough) return;
            root.dragX = Math.max(64, Math.min(root.screenW - root.width - 8, startX + dx));
            root.dragY = Math.max(12, Math.min(root.screenH - root.height - 8, startY + dy));
        }

        onReleased: {
            if (!movedEnough) {
                root.dragging = false;
                root.clicked(root.itemIndex);
            } else {
                root.moved(root.itemIndex, root.dragX, root.dragY);
                root.dragging = false;
            }
        }

        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? 0.1 : -0.1;
            const nextScale = Math.max(0.5, Math.min(2.4, root.itemScale + delta));
            root.updated(root.itemIndex, { scale: nextScale });
        }
    }

    // Compact hover controls (rotate, scale, remove)
    Rectangle {
        id: controlsRow
        property bool hovered: false
        visible: root.hovered || root.selected
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 4
        width: rowLayout.implicitWidth + 12
        height: 26
        radius: 13
        color: Qt.rgba(0.06, 0.09, 0.16, 0.88)
        border.color: Qt.rgba(1, 1, 1, 0.20)
        border.width: 1

        HoverHandler {
            onHoveredChanged: controlsRow.hovered = hovered
        }

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "−"
                color: "#e2e8f0"
                font.pixelSize: 14
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updated(root.itemIndex, { scale: Math.max(0.5, root.itemScale - 0.15) })
                }
            }
            Text {
                text: "+"
                color: "#e2e8f0"
                font.pixelSize: 14
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updated(root.itemIndex, { scale: Math.min(2.4, root.itemScale + 0.15) })
                }
            }
            Text {
                text: "↻"
                color: "#93c5fd"
                font.pixelSize: 13
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updated(root.itemIndex, { rotation: (root.itemRot + 15) % 360 })
                }
            }
            Text {
                text: "✕"
                color: "#fca5a5"
                font.pixelSize: 12
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removed(root.itemIndex)
                }
            }
        }
    }
}
