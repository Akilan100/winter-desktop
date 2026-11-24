import QtQuick

Item {
    id: root

    required property real screenW
    required property real screenH
    required property bool active

    signal finished()

    width: 220
    height: 74
    visible: active

    property real sleighX: -240
    property real bobPhase: 0

    x: sleighX
    y: screenH - height - 14 + Math.sin(bobPhase) * 4

    onActiveChanged: {
        if (active) {
            sleighX = -240;
            bobPhase = 0;
        }
    }

    FrameAnimation {
        running: root.active
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.001, frameTime));
            root.sleighX += 230 * dt;
            root.bobPhase += dt * 6;
            santaCanvas.requestPaint();
            if (root.sleighX > root.screenW + 40) {
                root.finished();
            }
        }
    }

    Canvas {
        id: santaCanvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0) return;
            ctx.clearRect(0, 0, w, h);

            // Sleigh runners + struts
            ctx.strokeStyle = "#facc15";
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(14, h - 8);
            ctx.lineTo(86, h - 8);
            ctx.quadraticCurveTo(98, h - 8, 100, h - 18);
            ctx.moveTo(30, h - 14); ctx.lineTo(30, h - 8);
            ctx.moveTo(72, h - 14); ctx.lineTo(72, h - 8);
            ctx.stroke();

            // Red sleigh body
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.roundedRect(18, h - 34, 68, 22, 8, 8);
            ctx.fill();
            ctx.fillStyle = "#facc15";
            ctx.fillRect(18, h - 34, 68, 4);

            // Gift sack
            ctx.fillStyle = "#92400e";
            ctx.beginPath();
            ctx.arc(34, h - 38, 12, 0, Math.PI * 2);
            ctx.fill();

            // Santa
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.arc(58, h - 38, 10, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#fed7aa";
            ctx.beginPath();
            ctx.arc(60, h - 50, 7, 0, Math.PI * 2);
            ctx.fill();
            // Beard
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(62, h - 46, 6, 0, Math.PI);
            ctx.fill();
            // Santa hat
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.moveTo(52, h - 54);
            ctx.lineTo(66, h - 54);
            ctx.lineTo(56, h - 64);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(55, h - 64, 3, 0, Math.PI * 2);
            ctx.fill();

            // Reins connecting Santa to both reindeer
            ctx.strokeStyle = "#fde047";
            ctx.lineWidth = 1.8;
            ctx.beginPath();
            ctx.moveTo(66, h - 38);
            ctx.quadraticCurveTo(102, h - 28, 146, h - 34);
            ctx.lineTo(194, h - 34);
            ctx.stroke();

            // Two reindeer
            for (let rx of [136, 184]) {
                ctx.fillStyle = "#92400e";
                ctx.beginPath();
                ctx.roundedRect(rx - 12, h - 30, 24, 12, 5, 5);
                ctx.fill();
                // Legs
                ctx.strokeStyle = "#78350f";
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.moveTo(rx - 8, h - 18); ctx.lineTo(rx - 10, h - 8);
                ctx.moveTo(rx + 8, h - 18); ctx.lineTo(rx + 12, h - 8);
                ctx.stroke();
                // Head
                ctx.fillStyle = "#92400e";
                ctx.beginPath();
                ctx.arc(rx + 12, h - 34, 6, 0, Math.PI * 2);
                ctx.fill();
                // Antlers
                ctx.strokeStyle = "#d97706";
                ctx.lineWidth = 1.8;
                ctx.beginPath();
                ctx.moveTo(rx + 10, h - 39); ctx.lineTo(rx + 6, h - 48);
                ctx.moveTo(rx + 12, h - 39); ctx.lineTo(rx + 16, h - 48);
                ctx.stroke();
                // Rudolph red nose on lead reindeer
                if (rx === 184) {
                    ctx.fillStyle = "#ef4444";
                    ctx.beginPath();
                    ctx.arc(rx + 18, h - 34, 2.8, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
    }
}
