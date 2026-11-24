import QtQuick

Item {
    id: root

    required property int itemIndex
    required property var itemData
    required property var windowRects
    required property real screenW
    required property real screenH
    required property bool selected

    signal clicked(int idx)
    signal moved(int idx, real nx, real ny, string attachedClass, real offsetX, string attachedAddr)

    readonly property var sizeScales: [0.55, 0.78, 1.0, 1.28, 1.58]
    readonly property int sizeLevel: itemData ? Math.max(0, Math.min(4, itemData.sizeLevel !== undefined ? itemData.sizeLevel : 2)) : 2
    readonly property real itemScale: sizeScales[sizeLevel]
    readonly property bool isAttached: itemData ? Boolean((itemData.attachedAddr && itemData.attachedAddr.length > 0) || (itemData.attachedClass && itemData.attachedClass.length > 0)) : false

    width: 190 * itemScale
    height: 250 * itemScale

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property string snapHint: ""

    function resolvePosition() {
        if (!itemData) return { x: 0, y: 0 };
        const hasAddr = itemData.attachedAddr && itemData.attachedAddr.length > 0;
        const hasCls = itemData.attachedClass && itemData.attachedClass.length > 0;
        if ((hasAddr || hasCls) && windowRects) {
            for (let i = 0; i < windowRects.length; i++) {
                const wr = windowRects[i];
                if ((hasAddr && wr.addr === itemData.attachedAddr) || (!hasAddr && wr.cls === itemData.attachedClass)) {
                    const nx = Math.max(wr.x, Math.min(wr.x + wr.w - width, wr.x + (itemData.offsetX || 0)));
                    const ny = wr.y - height + 16 * itemScale;
                    return { x: nx, y: ny };
                }
            }
        }
        return {
            x: Math.max(64, Math.min(screenW - width - 12, itemData.x || 200)),
            y: Math.max(12, Math.min(screenH - height - 8, itemData.y || 200))
        };
    }

    readonly property var resolved: resolvePosition()
    x: dragging ? dragX : resolved.x
    y: dragging ? dragY : resolved.y

    Behavior on x {
        enabled: !root.dragging && !root.isAttached
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !root.dragging && !root.isAttached
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 18
        color: "transparent"
        border.width: root.selected || root.snapHint.length > 0 ? 2 : 0
        border.color: root.snapHint.length > 0 ? "#4ade80" : "#60a5fa"
        opacity: 0.85
    }

    TreeCanvas {
        anchors.fill: parent
        topper: root.itemData ? (root.itemData.topper || "star") : "star"
        ornaments: root.itemData && root.itemData.ornaments ? root.itemData.ornaments : ["baubles", "lights"]
        showGifts: true
    }

    Rectangle {
        visible: root.dragging && root.snapHint.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: snapText.implicitWidth + 16
        height: 24
        radius: 12
        color: "#0f172a"
        border.color: "#4ade80"
        border.width: 1
        Text {
            id: snapText
            anchors.centerIn: parent
            text: "Place on " + root.snapHint
            color: "#dcfce7"
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real pressX: 0
        property real pressY: 0
        property real startItemX: 0
        property real startItemY: 0
        property bool movedEnough: false

        onPressed: mouse => {
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            pressX = pt.x;
            pressY = pt.y;
            startItemX = root.x;
            startItemY = root.y;
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

            let nx = Math.max(64, Math.min(root.screenW - root.width - 8, startItemX + dx));
            let ny = Math.max(12, Math.min(root.screenH - root.height - 8, startItemY + dy));

            let foundSnap = "";
            const footY = ny + root.height - 16 * root.itemScale;
            const centerX = nx + root.width / 2;
            if (root.windowRects) {
                for (let i = 0; i < root.windowRects.length; i++) {
                    const wr = root.windowRects[i];
                    if (centerX >= wr.x && centerX <= wr.x + wr.w && Math.abs(footY - wr.y) < 26) {
                        ny = wr.y - root.height + 16 * root.itemScale;
                        foundSnap = wr.cls;
                        break;
                    }
                }
            }
            root.snapHint = foundSnap;
            root.dragX = nx;
            root.dragY = ny;
        }

        onReleased: {
            if (!movedEnough) {
                root.dragging = false;
                root.snapHint = "";
                root.clicked(root.itemIndex);
                return;
            }
            let attached = "";
            let attachedAddr = "";
            let offX = 0;
            const footY = root.dragY + root.height - 16 * root.itemScale;
            const centerX = root.dragX + root.width / 2;
            if (root.windowRects) {
                for (let i = 0; i < root.windowRects.length; i++) {
                    const wr = root.windowRects[i];
                    if (centerX >= wr.x && centerX <= wr.x + wr.w && Math.abs(footY - wr.y) < 26) {
                        attached = wr.cls;
                        attachedAddr = wr.addr || "";
                        offX = root.dragX - wr.x;
                        break;
                    }
                }
            }
            root.snapHint = "";
            root.moved(root.itemIndex, root.dragX, root.dragY, attached, offX, attachedAddr);
            root.dragging = false;
        }
    }
}
