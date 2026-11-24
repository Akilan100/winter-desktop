import QtQuick

Item {
    id: root

    property string kind: "star"

    onKindChanged: decorCanvas.requestPaint()

    // Subtle glow pulse for star / candle / lights
    property real pulse: 0
    NumberAnimation on pulse {
        from: 0; to: Math.PI * 2; duration: 2600; loops: Animation.Infinite
        running: root.visible && (root.kind === "star" || root.kind === "candle" || root.kind === "lights")
    }

    Rectangle {
        visible: root.kind === "star" || root.kind === "candle"
        anchors.centerIn: parent
        width: parent.width * 0.72
        height: width
        radius: width / 2
        color: root.kind === "star" ? "#fde047" : "#fb923c"
        opacity: 0.14 + 0.10 * Math.sin(root.pulse)
        scale: 0.95 + 0.08 * Math.sin(root.pulse)
    }

    Canvas {
        id: decorCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0) return;
            ctx.clearRect(0, 0, w, h);

            ctx.save();
            const baseW = (root.kind === "lights") ? 260.0 : 120.0;
            const baseH = (root.kind === "lights") ? 70.0 : 120.0;
            const s = Math.min(w / baseW, h / baseH);
            ctx.translate((w - baseW * s) / 2, (h - baseH * s) / 2);
            ctx.scale(s, s);

            const cx = baseW / 2;
            const cy = baseH / 2;

            if (root.kind === "star") {
                ctx.save();
                ctx.shadowColor = "#fde047";
                ctx.shadowBlur = 18;
                const g = ctx.createRadialGradient(cx - 6, cy - 6, 4, cx, cy, 44);
                g.addColorStop(0, "#fef9c3");
                g.addColorStop(0.5, "#facc15");
                g.addColorStop(1, "#eab308");
                ctx.fillStyle = g;
                ctx.beginPath();
                for (let k = 0; k < 10; k++) {
                    const r = (k % 2 === 0) ? 42 : 18;
                    const ang = -Math.PI / 2 + k * Math.PI / 5;
                    const px = cx + Math.cos(ang) * r;
                    const py = cy + Math.sin(ang) * r;
                    if (k === 0) ctx.moveTo(px, py);
                    else ctx.lineTo(px, py);
                }
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            } else if (root.kind === "lights") {
                ctx.strokeStyle = "#1e293b";
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.moveTo(8, 14);
                ctx.quadraticCurveTo(65, 34, 130, 16);
                ctx.quadraticCurveTo(195, 34, 252, 14);
                ctx.stroke();
                const cols = ["#ef4444", "#facc15", "#38bdf8", "#4ade80", "#f472b6", "#facc15", "#ef4444"];
                for (let i = 0; i < 7; i++) {
                    const bx = 24 + i * 35;
                    const by = (i % 2 === 0) ? 26 : 30;
                    ctx.fillStyle = "#334155";
                    ctx.fillRect(bx - 3, by - 8, 6, 6);
                    ctx.save();
                    ctx.shadowColor = cols[i];
                    ctx.shadowBlur = 12;
                    ctx.fillStyle = cols[i];
                    ctx.beginPath();
                    ctx.ellipse(bx - 6, by - 2, 12, 16);
                    ctx.fill();
                    ctx.restore();
                }
            } else if (root.kind === "wreath") {
                ctx.strokeStyle = "#15803d";
                ctx.lineWidth = 18;
                ctx.beginPath();
                ctx.arc(cx, cy, 34, 0, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = "#22c55e";
                ctx.lineWidth = 8;
                ctx.setLineDash([6, 8]);
                ctx.beginPath();
                ctx.arc(cx, cy, 34, 0, Math.PI * 2);
                ctx.stroke();
                ctx.setLineDash([]);
                // Berries
                ctx.fillStyle = "#ef4444";
                for (let a of [0.4, 1.6, 2.8, 4.0, 5.2]) {
                    ctx.beginPath();
                    ctx.arc(cx + Math.cos(a) * 34, cy + Math.sin(a) * 34, 4, 0, Math.PI * 2);
                    ctx.fill();
                }
                // Red bow at bottom
                ctx.fillStyle = "#dc2626";
                ctx.beginPath();
                ctx.moveTo(cx, cy + 34);
                ctx.lineTo(cx - 14, cy + 24);
                ctx.lineTo(cx - 14, cy + 44);
                ctx.closePath();
                ctx.moveTo(cx, cy + 34);
                ctx.lineTo(cx + 14, cy + 24);
                ctx.lineTo(cx + 14, cy + 44);
                ctx.closePath();
                ctx.fill();
            } else if (root.kind === "candle") {
                ctx.fillStyle = "#fef3c7";
                ctx.beginPath();
                ctx.roundedRect(cx - 16, cy - 6, 32, 52, 5, 5);
                ctx.fill();
                ctx.fillStyle = "#b45309";
                ctx.fillRect(cx - 2, cy - 14, 4, 8);
                ctx.save();
                ctx.shadowColor = "#fb923c";
                ctx.shadowBlur = 14;
                ctx.fillStyle = "#f97316";
                ctx.beginPath();
                ctx.moveTo(cx, cy - 38);
                ctx.quadraticCurveTo(cx + 12, cy - 20, cx, cy - 12);
                ctx.quadraticCurveTo(cx - 12, cy - 20, cx, cy - 38);
                ctx.fill();
                ctx.fillStyle = "#fef08a";
                ctx.beginPath();
                ctx.arc(cx, cy - 20, 4, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();
            } else if (root.kind === "stocking") {
                ctx.fillStyle = "#dc2626";
                ctx.beginPath();
                ctx.roundedRect(cx - 16, cy - 32, 32, 54, 8, 8);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(cx - 16, cy + 6, 46, 24, 12, 12);
                ctx.fill();
                ctx.fillStyle = "#f8fafc";
                ctx.beginPath();
                ctx.roundedRect(cx - 19, cy - 36, 38, 14, 6, 6);
                ctx.fill();
            } else if (root.kind === "candycane") {
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 14;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(cx + 10, cy + 40);
                ctx.lineTo(cx + 10, cy - 16);
                ctx.arc(cx - 6, cy - 16, 16, 0, Math.PI, true);
                ctx.stroke();
                ctx.strokeStyle = "#ef4444";
                ctx.lineWidth = 7;
                for (let y = cy - 10; y <= cy + 34; y += 16) {
                    ctx.beginPath();
                    ctx.moveTo(cx + 4, y);
                    ctx.lineTo(cx + 16, y - 6);
                    ctx.stroke();
                }
            } else if (root.kind === "gift") {
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.roundedRect(cx - 32, cy - 22, 64, 56, 6, 6);
                ctx.fill();
                ctx.fillStyle = "#dc2626";
                ctx.beginPath();
                ctx.roundedRect(cx - 36, cy - 28, 72, 14, 4, 4);
                ctx.fill();
                ctx.fillStyle = "#facc15";
                ctx.fillRect(cx - 6, cy - 28, 12, 62);
                ctx.fillRect(cx - 32, cy + 2, 64, 10);
            } else if (root.kind === "snowglobe") {
                ctx.fillStyle = "#78350f";
                ctx.beginPath();
                ctx.roundedRect(cx - 28, cy + 24, 56, 18, 6, 6);
                ctx.fill();
                const g = ctx.createRadialGradient(cx - 10, cy - 14, 6, cx, cy - 4, 38);
                g.addColorStop(0, "rgba(224, 242, 254, 0.92)");
                g.addColorStop(1, "rgba(56, 189, 248, 0.45)");
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(cx, cy - 4, 36, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = "rgba(255,255,255,0.8)";
                ctx.lineWidth = 2;
                ctx.stroke();
                // Mini tree inside
                ctx.fillStyle = "#15803d";
                ctx.beginPath();
                ctx.moveTo(cx, cy - 24);
                ctx.lineTo(cx + 14, cy + 12);
                ctx.lineTo(cx - 14, cy + 12);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.arc(cx - 12, cy - 12, 2, 0, Math.PI * 2);
                ctx.arc(cx + 14, cy - 6, 2, 0, Math.PI * 2);
                ctx.arc(cx - 6, cy + 2, 1.8, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.kind === "cocoa") {
                ctx.strokeStyle = "#dc2626";
                ctx.lineWidth = 7;
                ctx.beginPath();
                ctx.arc(cx + 24, cy + 6, 12, -Math.PI / 2, Math.PI / 2);
                ctx.stroke();
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.roundedRect(cx - 26, cy - 14, 50, 48, 8, 8);
                ctx.fill();
                ctx.fillStyle = "#78350f";
                ctx.beginPath();
                ctx.ellipse(cx - 22, cy - 16, 42, 10);
                ctx.fill();
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.roundedRect(cx - 12, cy - 18, 10, 8, 2, 2);
                ctx.roundedRect(cx + 2, cy - 16, 10, 8, 2, 2);
                ctx.fill();
            } else if (root.kind === "gingerbread") {
                ctx.fillStyle = "#b45309";
                ctx.beginPath();
                ctx.arc(cx, cy - 24, 14, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(cx - 14, cy - 12, 28, 34, 8, 8);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(cx - 30, cy - 8, 60, 12, 6, 6);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(cx - 14, cy + 16, 11, 24, 5, 5);
                ctx.roundedRect(cx + 3, cy + 16, 11, 24, 5, 5);
                ctx.fill();
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.arc(cx - 5, cy - 26, 2.2, 0, Math.PI * 2);
                ctx.arc(cx + 5, cy - 26, 2.2, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.arc(cx, cy - 2, 3, 0, Math.PI * 2);
                ctx.arc(cx, cy + 8, 3, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.kind === "holly") {
                ctx.fillStyle = "#15803d";
                ctx.beginPath();
                ctx.ellipse(cx - 34, cy - 14, 34, 18);
                ctx.fill();
                ctx.fillStyle = "#16a34a";
                ctx.beginPath();
                ctx.ellipse(cx, cy - 4, 34, 18);
                ctx.fill();
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.arc(cx - 4, cy + 6, 7, 0, Math.PI * 2);
                ctx.arc(cx + 8, cy + 8, 7, 0, Math.PI * 2);
                ctx.arc(cx + 2, cy - 4, 7, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.kind === "red_bauble" || root.kind === "gold_bauble") {
                const isRed = root.kind === "red_bauble";
                ctx.strokeStyle = "#facc15";
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(cx, cy - 34, 6, 0, Math.PI * 2);
                ctx.stroke();
                ctx.fillStyle = "#eab308";
                ctx.beginPath();
                ctx.roundedRect(cx - 8, cy - 30, 16, 10, 3, 3);
                ctx.fill();
                const g = ctx.createRadialGradient(cx - 12, cy - 6, 4, cx, cy + 6, 36);
                g.addColorStop(0, isRed ? "#fca5a5" : "#fef9c3");
                g.addColorStop(0.5, isRed ? "#ef4444" : "#facc15");
                g.addColorStop(1, isRed ? "#991b1b" : "#a16207");
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(cx, cy + 6, 32, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.kind === "bells") {
                ctx.fillStyle = "#facc15";
                for (let side of [-16, 16]) {
                    ctx.save();
                    ctx.translate(cx + side, cy + 4);
                    ctx.rotate(side < 0 ? -0.25 : 0.25);
                    ctx.beginPath();
                    ctx.arc(0, -10, 14, Math.PI, 0);
                    ctx.lineTo(18, 16);
                    ctx.lineTo(-18, 16);
                    ctx.closePath();
                    ctx.fill();
                    ctx.fillStyle = "#ca8a04";
                    ctx.beginPath();
                    ctx.arc(0, 18, 5, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                    ctx.fillStyle = "#facc15";
                }
                ctx.fillStyle = "#dc2626";
                ctx.beginPath();
                ctx.arc(cx, cy - 20, 7, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.kind === "boat") {
                ctx.fillStyle = "#92400e";
                ctx.beginPath();
                ctx.moveTo(cx - 38, cy + 8);
                ctx.lineTo(cx + 38, cy + 8);
                ctx.lineTo(cx + 24, cy + 30);
                ctx.lineTo(cx - 24, cy + 30);
                ctx.closePath();
                ctx.fill();
                ctx.strokeStyle = "#78350f";
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.moveTo(cx, cy + 8);
                ctx.lineTo(cx, cy - 34);
                ctx.stroke();
                ctx.fillStyle = "#f8fafc";
                ctx.beginPath();
                ctx.moveTo(cx + 2, cy - 32);
                ctx.lineTo(cx + 30, cy + 2);
                ctx.lineTo(cx + 2, cy + 2);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.roundedRect(cx - 22, cy - 6, 16, 14, 2, 2);
                ctx.fill();
            } else if (root.kind === "santahat") {
                ctx.fillStyle = "#dc2626";
                ctx.beginPath();
                ctx.moveTo(cx - 34, cy + 20);
                ctx.quadraticCurveTo(cx - 6, cy - 38, cx + 34, cy - 10);
                ctx.lineTo(cx + 28, cy + 20);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.roundedRect(cx - 38, cy + 14, 72, 16, 8, 8);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(cx + 36, cy - 8, 10, 0, Math.PI * 2);
                ctx.fill();
            }

            ctx.restore();
        }
    }
}
