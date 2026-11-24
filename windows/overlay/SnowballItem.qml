import QtQuick

Item {
    id: root

    required property int itemIndex
    required property var itemData
    required property var allSnowballs
    required property var windowRects
    required property real screenW
    required property real screenH
    required property bool selected

    signal clicked(int idx)
    signal rightClicked(int idx)
    signal moved(int idx, real nx, real ny, string attachedClass, real offsetX, string attachedAddr)
    signal stackRequested(int srcIdx, int dstIdx)
    signal splatRequested(int idx, real sx, real sy, real size)

    readonly property int tier: itemData ? (itemData.tier || 1) : 1
    readonly property real radius: itemData ? (itemData.radius || 20) : 20
    readonly property real rollAngle: itemData ? (itemData.rollAngle || 0) : 0
    readonly property bool isRolling: itemData ? Boolean(itemData.rolling) : false
    readonly property bool isAttached: itemData ? Boolean((itemData.attachedAddr && itemData.attachedAddr.length > 0) || (itemData.attachedClass && itemData.attachedClass.length > 0)) : false
    readonly property int launchSeq: itemData ? (itemData.launchSeq || 0) : 0
    readonly property real topRadius: Math.max(12, radius * 0.76)

    width: Math.max(36, radius * 2 + 16)
    height: tier === 2 ? (radius * 2 + topRadius * 1.7 + 16) : Math.max(36, radius * 2 + 16)

    property bool dragging: false
    property bool flying: false
    property real dragX: 0
    property real dragY: 0
    property real vx: 0
    property real vy: 0
    property int stackTargetIdx: -1
    property bool menuOpen: false

    onLaunchSeqChanged: {
        if (launchSeq > 0 && itemData) {
            dragX = Math.max(64, Math.min(screenW - width - 8, (itemData.x || 200) - width / 2));
            dragY = Math.max(12, Math.min(screenH - height - 4, (itemData.y || 200) - height + 8));
            vx = itemData.launchVx || 0;
            vy = itemData.launchVy || 0;
            dragging = false;
            flying = true;
        }
    }

    function resolvePosition() {
        if (!itemData) return { x: 0, y: 0 };
        const hasAddr = itemData.attachedAddr && itemData.attachedAddr.length > 0;
        const hasCls = itemData.attachedClass && itemData.attachedClass.length > 0;
        if ((hasAddr || hasCls) && windowRects) {
            for (let i = 0; i < windowRects.length; i++) {
                const wr = windowRects[i];
                if ((hasAddr && wr.addr === itemData.attachedAddr) || (!hasAddr && wr.cls === itemData.attachedClass)) {
                    const nx = Math.max(wr.x, Math.min(wr.x + wr.w - width, wr.x + (itemData.offsetX || 0)));
                    const ny = wr.y - height + 8;
                    return { x: nx, y: ny };
                }
            }
        }
        return {
            x: Math.max(64, Math.min(screenW - width - 8, (itemData.x || 200) - width / 2)),
            y: Math.max(12, Math.min(screenH - height - 4, (itemData.y || 200) - height + 8))
        };
    }

    readonly property var resolved: resolvePosition()
    x: (dragging || flying) ? dragX : resolved.x
    y: (dragging || flying) ? dragY : resolved.y

    Behavior on x {
        enabled: !root.dragging && !root.flying && !root.isRolling && !root.isAttached
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !root.dragging && !root.flying && !root.isRolling && !root.isAttached
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // True 144Hz VSync projectile physics when thrown or launched off a moving window!
    FrameAnimation {
        id: flyAnim
        running: root.flying
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.001, frameTime));
            root.vy += 1150 * dt;
            let nx = root.dragX + root.vx * dt;
            let ny = root.dragY + root.vy * dt;

            const cx = nx + root.width / 2;
            const footY = ny + root.height - 8;
            const speed = Math.hypot(root.vx, root.vy);

            // Check collision with another snowball
            if (root.allSnowballs) {
                for (let i = 0; i < root.allSnowballs.length; i++) {
                    if (i === root.itemIndex) continue;
                    const ob = root.allSnowballs[i];
                    let obX = ob.x;
                    let obY = ob.y - (ob.radius || 20);
                    if ((ob.attachedAddr || ob.attachedClass) && root.windowRects) {
                        for (let j = 0; j < root.windowRects.length; j++) {
                            const wr = root.windowRects[j];
                            if ((ob.attachedAddr && wr.addr === ob.attachedAddr) || (!ob.attachedAddr && wr.cls === ob.attachedClass)) {
                                const obW = Math.max(36, (ob.radius || 20) * 2 + 16);
                                obX = wr.x + (ob.offsetX || 0) + obW / 2;
                                obY = wr.y - (ob.radius || 20);
                                break;
                            }
                        }
                    }
                    const dist = Math.hypot(cx - obX, (ny + root.height / 2) - obY);
                    if (dist < root.radius + (ob.radius || 20) + 6) {
                        root.flying = false;
                        if (speed > 460) {
                            root.splatRequested(root.itemIndex, cx, ny + root.height / 2, root.radius * 2.4);
                        } else {
                            root.stackRequested(root.itemIndex, i);
                        }
                        return;
                    }
                }
            }

            // Check collision with window top ledges (jump from one window to another!)
            if (root.vy > 0 && root.windowRects) {
                for (let i = 0; i < root.windowRects.length; i++) {
                    const wr = root.windowRects[i];
                    if (cx >= wr.x && cx <= wr.x + wr.w && footY >= wr.y && footY <= wr.y + 28) {
                        root.flying = false;
                        if (speed > 580) {
                            StateStore.depositChunkSnow(wr.addr, cx, wr, root.screenW);
                            root.splatRequested(root.itemIndex, cx, wr.y, root.radius * 2.3);
                        } else {
                            StateStore.depositChunkSnow(wr.addr, cx, wr, root.screenW);
                            root.moved(root.itemIndex, cx, wr.y, wr.cls, nx - wr.x, wr.addr);
                        }
                        return;
                    }
                }
            }

            // Side walls bounce/splat
            if (nx <= 64 || nx + root.width >= root.screenW - 6) {
                root.flying = false;
                root.splatRequested(root.itemIndex, Math.max(70, Math.min(root.screenW - 20, cx)), ny + root.height / 2, root.radius * 2.2);
                return;
            }

            // Top edge -> fall back down
            if (ny < 0) {
                ny = 0;
                root.vy = Math.abs(root.vy) * 0.35;
            }

            // Ground hit
            if (footY >= root.screenH - 6) {
                root.flying = false;
                if (speed > 620) {
                    StateStore.depositChunkSnow("", cx, null, root.screenW);
                    root.splatRequested(root.itemIndex, cx, root.screenH - 14, root.radius * 2.4);
                } else {
                    root.moved(root.itemIndex, cx, root.screenH - 6, "", 0, "");
                }
                return;
            }

            root.dragX = nx;
            root.dragY = ny;
        }
    }

    // Stack target hint ring
    Rectangle {
        visible: root.stackTargetIdx >= 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        width: stackHintTxt.implicitWidth + 16
        height: 22
        radius: 11
        color: "#0f172a"
        border.color: "#38bdf8"
        border.width: 1
        Text {
            id: stackHintTxt
            anchors.centerIn: parent
            text: "Drop to stack!"
            color: "#e0f2fe"
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    Canvas {
        id: ballCanvas
        anchors.fill: parent
        property int t: root.tier
        property real r: root.radius
        property real ang: root.rollAngle
        onTChanged: requestPaint()
        onRChanged: requestPaint()
        onAngChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0) return;
            ctx.clearRect(0, 0, w, h);

            const cx = w / 2;
            const r1 = root.radius;
            const y1 = h - 8 - r1;

            function drawBall(bx, by, br, rot) {
                ctx.save();
                ctx.shadowColor = "rgba(15, 23, 42, 0.34)";
                ctx.shadowBlur = 10;
                ctx.shadowOffsetY = 4;
                const g = ctx.createRadialGradient(bx - br * 0.34, by - br * 0.34, br * 0.08, bx, by, br);
                g.addColorStop(0, "#ffffff");
                g.addColorStop(0.55, "#f8fafc");
                g.addColorStop(0.85, "#e2e8f0");
                g.addColorStop(1, "#bfdbfe");
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(bx, by, br, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();

                // Pure white & soft frost snow-grain texture
                ctx.save();
                ctx.translate(bx, by);
                ctx.rotate(rot);
                ctx.fillStyle = "rgba(255, 255, 255, 0.70)";
                ctx.beginPath();
                ctx.arc(-br * 0.28, -br * 0.28, Math.max(1.5, br * 0.16), 0, Math.PI * 2);
                ctx.arc(br * 0.22, -br * 0.16, Math.max(1.2, br * 0.10), 0, Math.PI * 2);
                ctx.arc(br * 0.10, br * 0.32, Math.max(1.0, br * 0.08), 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();

                // Crisp bright snow rim
                ctx.strokeStyle = "rgba(255, 255, 255, 0.94)";
                ctx.lineWidth = 1.3;
                ctx.beginPath();
                ctx.arc(bx, by, br - 0.6, 0, Math.PI * 2);
                ctx.stroke();
            }

            drawBall(cx, y1, r1, root.rollAngle);
            if (root.tier === 2) {
                const r2 = root.topRadius;
                const y2 = y1 - r1 - r2 * 0.68;
                drawBall(cx, y2, r2, 0);
            }
        }
    }

    // Hover / selection ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: root.tier === 2 ? 20 : width / 2
        color: "transparent"
        border.width: (dragArea.containsMouse || root.selected) ? 1.5 : 0
        border.color: "#60a5fa"
        opacity: 0.75
    }

    // Quick right-click / hover action pill above snowball
    Rectangle {
        id: quickMenu
        visible: root.menuOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: qRow.implicitWidth + 16
        height: 28
        radius: 14
        color: Qt.rgba(0.06, 0.09, 0.16, 0.92)
        border.color: Qt.rgba(0.58, 0.77, 0.99, 0.45)
        border.width: 1

        Row {
            id: qRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "+Grow"
                color: "#bae6fd"
                font.pixelSize: 11
                font.weight: Font.Medium
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.growSnowball(root.itemIndex, 5)
                }
            }
            Text {
                text: root.tier === 1 ? "Stack +1" : "Make Snowman!"
                color: "#86efac"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.menuOpen = false;
                        StateStore.promoteSnowballStack(root.itemIndex);
                    }
                }
            }
            Text {
                text: "✕"
                color: "#fca5a5"
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.menuOpen = false;
                        StateStore.removeSnowball(root.itemIndex);
                    }
                }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real pressX: 0
        property real pressY: 0
        property real startX: 0
        property real startY: 0
        property real lastX: 0
        property real lastY: 0
        property real lastTime: 0
        property real velX: 0
        property real velY: 0
        property bool movedEnough: false

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.menuOpen = !root.menuOpen;
                root.rightClicked(root.itemIndex);
                return;
            }
            root.menuOpen = false;
            root.flying = false;
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            pressX = pt.x;
            pressY = pt.y;
            startX = root.x;
            startY = root.y;
            lastX = pt.x;
            lastY = pt.y;
            lastTime = Date.now();
            velX = 0;
            velY = 0;
            root.dragX = root.x;
            root.dragY = root.y;
            movedEnough = false;
            root.dragging = true;
        }

        onPositionChanged: mouse => {
            if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) return;
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            const now = Date.now();
            const dt = Math.max(0.008, (now - lastTime) / 1000.0);
            velX = 0.6 * velX + 0.4 * ((pt.x - lastX) / dt);
            velY = 0.6 * velY + 0.4 * ((pt.y - lastY) / dt);
            lastX = pt.x;
            lastY = pt.y;
            lastTime = now;

            const dx = pt.x - pressX;
            const dy = pt.y - pressY;
            if (Math.abs(dx) > 4 || Math.abs(dy) > 4) movedEnough = true;
            if (!movedEnough) return;

            const nx = Math.max(64, Math.min(root.screenW - root.width - 8, startX + dx));
            const ny = Math.max(12, Math.min(root.screenH - root.height - 4, startY + dy));
            root.dragX = nx;
            root.dragY = ny;

            // Check if hovering over another snowball to stack!
            const cx = nx + root.width / 2;
            const cy = ny + root.height / 2;
            let foundTarget = -1;
            if (root.allSnowballs) {
                for (let i = 0; i < root.allSnowballs.length; i++) {
                    if (i === root.itemIndex) continue;
                    const ob = root.allSnowballs[i];
                    let obX = ob.x;
                    let obY = ob.y - (ob.radius || 20);
                    if ((ob.attachedAddr || ob.attachedClass) && root.windowRects) {
                        for (let j = 0; j < root.windowRects.length; j++) {
                            const wr = root.windowRects[j];
                            if ((ob.attachedAddr && wr.addr === ob.attachedAddr) || (!ob.attachedAddr && wr.cls === ob.attachedClass)) {
                                const obW = Math.max(36, (ob.radius || 20) * 2 + 16);
                                obX = wr.x + (ob.offsetX || 0) + obW / 2;
                                obY = wr.y - (ob.radius || 20);
                                break;
                            }
                        }
                    }
                    if (Math.hypot(cx - obX, cy - obY) < 60) {
                        foundTarget = i;
                        break;
                    }
                }
            }
            root.stackTargetIdx = foundTarget;
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton) return;
            if (!movedEnough) {
                root.dragging = false;
                root.stackTargetIdx = -1;
                root.clicked(root.itemIndex);
                return;
            }

            // 1. If dropped onto another snowball -> stack!
            if (root.stackTargetIdx >= 0) {
                const target = root.stackTargetIdx;
                root.stackTargetIdx = -1;
                root.dragging = false;
                root.stackRequested(root.itemIndex, target);
                return;
            }

            // 2. If released mid-swing with high velocity -> throw!
            const speed = Math.hypot(velX, velY);
            if (speed > 320) {
                root.vx = Math.max(-1400, Math.min(1400, velX));
                root.vy = Math.max(-1400, Math.min(1400, velY));
                root.dragging = false;
                root.flying = true;
                return;
            }

            // 3. Gentle drop -> snap to window ledge below or screen bottom
            const cx = root.dragX + root.width / 2;
            const footY = root.dragY + root.height - 8;
            let attached = "";
            let attachedAddr = "";
            let offX = 0;
            let finalY = footY;

            if (root.windowRects) {
                for (let i = 0; i < root.windowRects.length; i++) {
                    const wr = root.windowRects[i];
                    if (cx >= wr.x && cx <= wr.x + wr.w && Math.abs(footY - wr.y) < 32) {
                        attached = wr.cls;
                        attachedAddr = wr.addr || "";
                        offX = root.dragX - wr.x;
                        finalY = wr.y;
                        break;
                    }
                }
            }
            if (!attached && footY > root.screenH - 48) {
                finalY = root.screenH - 6;
            }
            root.moved(root.itemIndex, cx, finalY, attached, offX, attachedAddr);
            root.dragging = false;
        }

        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? 3 : -3;
            StateStore.growSnowball(root.itemIndex, delta);
        }
    }
}
