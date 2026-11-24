import QtQuick

Item {
    id: root

    required property real screenW
    required property real screenH
    required property bool active
    required property var snowmen

    signal closed()
    signal sweepStep(real px, real pw)

    width: 156
    height: 78
    visible: active

    property real plowX: Math.max(80, screenW - 240)
    property real snowWedge: 0.0
    property real wheelPhase: 0
    property bool facingRight: false
    property bool bladeRaised: false
    property bool honking: false
    property bool beaconOn: true
    property int driveDir: 0 // -1 = left, 0 = parked, 1 = right
    property bool autoSweep: false
    property bool dragging: false
    property bool controlsPinned: true

    readonly property bool showControls: active && (controlsPinned || hoverArea.containsMouse || ctrlHover.hovered || dragging)

    y: screenH - height - 4
    x: plowX

    onActiveChanged: {
        if (active) {
            plowX = Math.max(80, screenW - 240);
            snowWedge = 0.0;
            facingRight = false;
            bladeRaised = false;
            honking = false;
            driveDir = 0;
            autoSweep = false;
            controlsPinned = true;
            plowCanvas.requestPaint();
        }
    }

    function moveBy(dx) {
        if (Math.abs(dx) < 0.2) return;
        facingRight = dx > 0;
        const minX = 66;
        const maxX = Math.max(minX, screenW - width - 8);
        const nextX = Math.max(minX, Math.min(maxX, plowX + dx));
        const moved = Math.abs(nextX - plowX);
        plowX = nextX;
        wheelPhase += (dx > 0 ? 1 : -1) * moved * 0.18;

        if (!bladeRaised && moved > 0.5) {
            snowWedge = Math.min(1.0, snowWedge + moved * 0.0035);
            const bladeX = facingRight ? (plowX + width - 48) : plowX;
            sweepStep(bladeX, 54);
        }

        // Politely honk & raise blade if approaching a ground snowman
        if (!bladeRaised && snowmen) {
            for (let i = 0; i < snowmen.length; i++) {
                const sm = snowmen[i];
                if ((!sm.attachedClass || sm.attachedClass === "") && sm.y > screenH - 260) {
                    const smCenter = sm.x + 70;
                    const bladeFront = facingRight ? (plowX + width - 10) : (plowX + 10);
                    if (Math.abs(smCenter - bladeFront) < 42) {
                        bladeRaised = true;
                        honking = true;
                        honkTimer.restart();
                        break;
                    }
                }
            }
        }
        plowCanvas.requestPaint();
    }

    Timer {
        interval: 320
        running: root.active
        repeat: true
        onTriggered: {
            root.beaconOn = !root.beaconOn;
            plowCanvas.requestPaint();
        }
    }

    Timer {
        id: honkTimer
        interval: 1100
        repeat: false
        onTriggered: root.honking = false
    }

    FrameAnimation {
        running: root.active && (root.driveDir !== 0 || root.autoSweep)
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.001, frameTime));
            const dir = root.autoSweep ? -1 : root.driveDir;
            const step = dir * 230 * dt;
            root.moveBy(step);

            if (root.autoSweep && root.plowX <= 68) {
                root.autoSweep = false;
                root.driveDir = 0;
                root.snowWedge = 0.0;
                StateStore.clearSnowhush();
                plowCanvas.requestPaint();
            } else if (!root.autoSweep && ((dir < 0 && root.plowX <= 68) || (dir > 0 && root.plowX >= root.screenW - root.width - 10))) {
                root.driveDir = 0;
            }
        }
    }

    // Cute "Beep!" speech bubble
    Rectangle {
        visible: root.honking
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: ctrlBar.visible ? ctrlBar.top : parent.top
        anchors.bottomMargin: 6
        width: beepTxt.implicitWidth + 16
        height: 24
        radius: 12
        color: "#fef08a"
        border.color: "#ca8a04"
        border.width: 1
        Text {
            id: beepTxt
            anchors.centerIn: parent
            text: "Beep! 🚜"
            color: "#422006"
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    // Manual Bulldozer Control Bar right above the tractor
    Rectangle {
        id: ctrlBar
        visible: root.showControls
        x: Math.round((parent.width - width) / 2 + (root.facingRight ? -8 : 8))
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: ctrlRow.implicitWidth + 16
        height: 30
        radius: 15
        color: Qt.rgba(0.06, 0.08, 0.14, 0.92)
        border.color: Qt.rgba(0.98, 0.80, 0.08, 0.45)
        border.width: 1

        HoverHandler { id: ctrlHover }

        Row {
            id: ctrlRow
            anchors.centerIn: parent
            spacing: 8

            // Drive Left (hold to drive)
            Rectangle {
                width: 26; height: 22; radius: 11
                color: leftMa.pressed || root.driveDir === -1 ? "#eab308" : (leftMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                Text { anchors.centerIn: parent; text: "◀"; color: leftMa.pressed || root.driveDir === -1 ? "#422006" : "#fef08a"; font.pixelSize: 11 }
                MouseArea {
                    id: leftMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: { root.autoSweep = false; root.driveDir = -1; }
                    onReleased: { if (root.driveDir === -1) root.driveDir = 0; }
                }
            }

            // Drive Right (hold to drive)
            Rectangle {
                width: 26; height: 22; radius: 11
                color: rightMa.pressed || root.driveDir === 1 ? "#eab308" : (rightMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                Text { anchors.centerIn: parent; text: "▶"; color: rightMa.pressed || root.driveDir === 1 ? "#422006" : "#fef08a"; font.pixelSize: 11 }
                MouseArea {
                    id: rightMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: { root.autoSweep = false; root.driveDir = 1; }
                    onReleased: { if (root.driveDir === 1) root.driveDir = 0; }
                }
            }

            // Blade Up/Down toggle
            Rectangle {
                width: blTxt.implicitWidth + 12; height: 22; radius: 11
                color: root.bladeRaised ? Qt.rgba(0.23, 0.51, 0.96, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                Text { id: blTxt; anchors.centerIn: parent; text: root.bladeRaised ? "Blade ↑" : "Blade ↓"; color: "#e2e8f0"; font.pixelSize: 10; font.weight: Font.Medium }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.bladeRaised = !root.bladeRaised;
                        plowCanvas.requestPaint();
                    }
                }
            }

            // 1-click Sweep across bottom
            Rectangle {
                width: swTxt.implicitWidth + 12; height: 22; radius: 11
                color: root.autoSweep ? "#ca8a04" : Qt.rgba(1, 1, 1, 0.08)
                Text { id: swTxt; anchors.centerIn: parent; text: "Sweep"; color: "#fef08a"; font.pixelSize: 10; font.weight: Font.Medium }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.bladeRaised = false;
                        root.autoSweep = !root.autoSweep;
                    }
                }
            }

            // Close / Park away
            Rectangle {
                width: 22; height: 22; radius: 11
                color: clsMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.38) : Qt.rgba(1, 1, 1, 0.08)
                Text { anchors.centerIn: parent; text: "✕"; color: "#fca5a5"; font.pixelSize: 10 }
                MouseArea {
                    id: clsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closed()
                }
            }
        }
    }

    Canvas {
        id: plowCanvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0) return;
            ctx.clearRect(0, 0, w, h);

            ctx.save();
            if (root.facingRight) {
                ctx.translate(w, 0);
                ctx.scale(-1, 1);
            }

            // Snow wedge pushed in front of the blade (left side in local coords)
            if (!root.bladeRaised && root.snowWedge > 0.05) {
                const sw = 22 + 22 * root.snowWedge;
                const sh = 14 + 20 * root.snowWedge;
                const g = ctx.createLinearGradient(0, h - sh, sw, h);
                g.addColorStop(0, "#ffffff");
                g.addColorStop(1, "#cbd5e1");
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo(38, h - 6);
                ctx.lineTo(38 - sw, h - 6);
                ctx.quadraticCurveTo(38 - sw * 0.45, h - 6 - sh, 38, h - 6 - sh * 0.85);
                ctx.closePath();
                ctx.fill();
            }

            const bladeLift = root.bladeRaised ? -10 : 0;

            // Curved front plow blade
            ctx.fillStyle = "#eab308";
            ctx.strokeStyle = "#854d0e";
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(44, h - 36 + bladeLift);
            ctx.quadraticCurveTo(30, h - 20 + bladeLift, 38, h - 6 + bladeLift);
            ctx.lineTo(48, h - 6 + bladeLift);
            ctx.quadraticCurveTo(40, h - 20 + bladeLift, 50, h - 36 + bladeLift);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();

            // Hydraulic arm
            ctx.strokeStyle = "#475569";
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.moveTo(46, h - 20 + bladeLift);
            ctx.lineTo(66, h - 22);
            ctx.stroke();

            // Main yellow tractor body
            ctx.fillStyle = "#facc15";
            ctx.beginPath();
            ctx.roundedRect(62, h - 40, 68, 24, 5, 5);
            ctx.fill();
            ctx.strokeStyle = "#a16207";
            ctx.lineWidth = 1.2;
            ctx.stroke();

            // Cab
            ctx.fillStyle = "#eab308";
            ctx.beginPath();
            ctx.roundedRect(82, h - 62, 40, 24, 5, 5);
            ctx.fill();
            ctx.stroke();

            // Cab window
            ctx.fillStyle = "#1e293b";
            ctx.beginPath();
            ctx.roundedRect(87, h - 57, 28, 15, 3, 3);
            ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.25)";
            ctx.fillRect(89, h - 55, 10, 4);

            // Beacon mount + flashing amber beacon
            ctx.fillStyle = "#334155";
            ctx.fillRect(98, h - 65, 8, 3);
            ctx.save();
            if (root.beaconOn) {
                ctx.shadowColor = "#fb923c";
                ctx.shadowBlur = 12;
            }
            ctx.fillStyle = root.beaconOn ? "#f97316" : "#9a3412";
            ctx.beginPath();
            ctx.arc(102, h - 67, 4.2, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // Exhaust pipe
            ctx.fillStyle = "#334155";
            ctx.fillRect(70, h - 52, 5, 12);

            // Headlight
            ctx.fillStyle = "#fef08a";
            ctx.beginPath();
            ctx.arc(62, h - 32, 3.5, 0, Math.PI * 2);
            ctx.fill();

            // Black caterpillar tread / wheels
            ctx.fillStyle = "#0f172a";
            ctx.beginPath();
            ctx.roundedRect(64, h - 20, 64, 16, 8, 8);
            ctx.fill();
            ctx.fillStyle = "#475569";
            for (let wx of [74, 96, 118]) {
                ctx.beginPath();
                ctx.arc(wx, h - 12, 5, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#94a3b8";
                ctx.beginPath();
                ctx.arc(wx + Math.cos(root.wheelPhase) * 2, h - 12 + Math.sin(root.wheelPhase) * 2, 1.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#475569";
            }

            ctx.restore();
        }
    }

    // Drag left/right with mouse to drive the bulldozer manually!
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real lastPtX: 0
        property bool movedEnough: false

        onPressed: mouse => {
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            lastPtX = pt.x;
            movedEnough = false;
            root.autoSweep = false;
            root.driveDir = 0;
            root.dragging = true;
        }

        onPositionChanged: mouse => {
            if (!pressed) return;
            const pt = mapToItem(root.parent, mouse.x, mouse.y);
            const dx = pt.x - lastPtX;
            if (Math.abs(dx) > 2) movedEnough = true;
            lastPtX = pt.x;
            root.moveBy(dx);
        }

        onReleased: {
            root.dragging = false;
            if (!movedEnough) {
                root.honking = true;
                root.controlsPinned = !root.controlsPinned;
                honkTimer.restart();
            }
        }
    }
}
