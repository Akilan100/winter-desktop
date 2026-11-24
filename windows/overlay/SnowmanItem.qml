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
    signal scaled(int idx, real newScale)

    readonly property real itemScale: itemData ? (itemData.scale || 1.0) : 1.0
    readonly property bool isAttached: itemData ? Boolean((itemData.attachedAddr && itemData.attachedAddr.length > 0) || (itemData.attachedClass && itemData.attachedClass.length > 0)) : false
    width: 140 * itemScale
    height: 175 * itemScale

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property string snapHint: ""

    // Compute live position: if attached to a visible window on active workspace, follow its top ledge at 144Hz!
    function resolvePosition() {
        if (!itemData) return { x: 0, y: 0, snapped: false };
        const hasAddr = itemData.attachedAddr && itemData.attachedAddr.length > 0;
        const hasCls = itemData.attachedClass && itemData.attachedClass.length > 0;
        if ((hasAddr || hasCls) && windowRects) {
            for (let i = 0; i < windowRects.length; i++) {
                const wr = windowRects[i];
                if ((hasAddr && wr.addr === itemData.attachedAddr) || (!hasAddr && wr.cls === itemData.attachedClass)) {
                    const nx = Math.max(wr.x, Math.min(wr.x + wr.w - width, wr.x + (itemData.offsetX || 0)));
                    const ny = wr.y - height + 14 * itemScale;
                    return { x: nx, y: ny, snapped: true };
                }
            }
        }
        return {
            x: Math.max(64, Math.min(screenW - width - 12, itemData.x || 100)),
            y: Math.max(12, Math.min(screenH - height - 8, itemData.y || 100)),
            snapped: false
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

    // Subtle idle breathing bob
    property real bobOffset: 0
    SequentialAnimation on bobOffset {
        loops: Animation.Infinite
        running: root.visible && !root.dragging
        NumberAnimation { from: 0; to: -3; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { from: -3; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }

    // Occasional blink
    property bool blinking: false
    Timer {
        interval: 4200 + (root.itemIndex * 900)
        running: root.visible
        repeat: true
        onTriggered: {
            root.blinking = true;
            blinkEnd.restart();
        }
    }
    Timer {
        id: blinkEnd
        interval: 140
        repeat: false
        onTriggered: root.blinking = false
    }

    // Selection / snap halo
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 18
        color: "transparent"
        border.width: root.selected || root.snapHint.length > 0 ? 2 : 0
        border.color: root.snapHint.length > 0 ? "#38bdf8" : "#60a5fa"
        opacity: 0.85
    }

    SnowmanCanvas {
        anchors.fill: parent
        anchors.topMargin: root.bobOffset
        anchors.bottomMargin: -root.bobOffset
        hat: root.itemData ? (root.itemData.hat || "tophat") : "tophat"
        face: root.itemData ? (root.itemData.face || "happy") : "happy"
        body: root.itemData ? (root.itemData.body || "mittens") : "mittens"
        clothes: root.itemData ? (root.itemData.clothes || "scarf") : "scarf"
        blinking: root.blinking
    }

    // Snap badge while dragging near a window ledge
    Rectangle {
        visible: root.dragging && root.snapHint.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: snapText.implicitWidth + 16
        height: 24
        radius: 12
        color: "#0f172a"
        border.color: "#38bdf8"
        border.width: 1
        Text {
            id: snapText
            anchors.centerIn: parent
            text: "Perch on " + root.snapHint
            color: "#e0f2fe"
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: dragArea
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

            // Check snap to window top ledge
            let foundSnap = "";
            const footY = ny + root.height - 14 * root.itemScale;
            const centerX = nx + root.width / 2;
            if (root.windowRects) {
                for (let i = 0; i < root.windowRects.length; i++) {
                    const wr = root.windowRects[i];
                    if (centerX >= wr.x && centerX <= wr.x + wr.w && Math.abs(footY - wr.y) < 26) {
                        ny = wr.y - root.height + 14 * root.itemScale;
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
            const footY = root.dragY + root.height - 14 * root.itemScale;
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

        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? 0.08 : -0.08;
            const nextScale = Math.max(0.55, Math.min(1.8, root.itemScale + delta));
            root.scaled(root.itemIndex, nextScale);
        }
    }
}
