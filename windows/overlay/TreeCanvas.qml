import QtQuick

Item {
    id: root

    property string topper: "star"
    property var ornaments: ["baubles", "lights"]
    property bool showGifts: true

    function hasOrnament(name) {
        return Array.isArray(ornaments) && ornaments.indexOf(name) !== -1;
    }

    onTopperChanged: treeCanvas.requestPaint()
    onOrnamentsChanged: treeCanvas.requestPaint()
    onShowGiftsChanged: treeCanvas.requestPaint()

    Canvas {
        id: treeCanvas
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
            const s = Math.min(w / 200.0, h / 260.0);
            ctx.translate((w - 200 * s) / 2, (h - 260 * s) / 2);
            ctx.scale(s, s);

            const cx = 100;

            // Ground shadow
            const sh = ctx.createRadialGradient(cx, 242, 6, cx, 242, 68);
            sh.addColorStop(0, "rgba(15, 23, 42, 0.42)");
            sh.addColorStop(1, "rgba(15, 23, 42, 0.0)");
            ctx.fillStyle = sh;
            ctx.beginPath();
            ctx.ellipse(cx - 68, 230, 136, 24);
            ctx.fill();

            // Trunk
            ctx.fillStyle = "#78350f";
            ctx.beginPath();
            ctx.roundedRect(cx - 12, 206, 24, 34, 4, 4);
            ctx.fill();
            ctx.fillStyle = "#92400e";
            ctx.fillRect(cx - 6, 206, 6, 34);

            // Layered pine tiers (bottom to top)
            const tiers = [
                { topY: 126, botY: 214, halfW: 76, c1: "#14532d", c2: "#166534" },
                { topY: 86,  botY: 168, halfW: 62, c1: "#166534", c2: "#15803d" },
                { topY: 52,  botY: 124, halfW: 46, c1: "#15803d", c2: "#16a34a" },
                { topY: 28,  botY: 82,  halfW: 30, c1: "#16a34a", c2: "#22c55e" }
            ];

            for (let i = 0; i < tiers.length; i++) {
                const t = tiers[i];
                ctx.save();
                ctx.shadowColor = "rgba(0, 0, 0, 0.28)";
                ctx.shadowBlur = 8;
                ctx.shadowOffsetY = 4;
                const g = ctx.createLinearGradient(cx - t.halfW, t.topY, cx + t.halfW, t.botY);
                g.addColorStop(0, t.c2);
                g.addColorStop(1, t.c1);
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo(cx, t.topY);
                ctx.quadraticCurveTo(cx + t.halfW * 0.55, (t.topY + t.botY) * 0.55, cx + t.halfW, t.botY - 6);
                ctx.quadraticCurveTo(cx, t.botY + 10, cx - t.halfW, t.botY - 6);
                ctx.quadraticCurveTo(cx - t.halfW * 0.55, (t.topY + t.botY) * 0.55, cx, t.topY);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            }

            // Garland
            if (root.hasOrnament("garland")) {
                ctx.strokeStyle = "#fde047";
                ctx.lineWidth = 3.2;
                ctx.lineCap = "round";
                const arcs = [
                    { x1: cx - 22, y1: 72, x2: cx + 24, y2: 82 },
                    { x1: cx - 38, y1: 112, x2: cx + 40, y2: 124 },
                    { x1: cx - 54, y1: 156, x2: cx + 56, y2: 170 },
                    { x1: cx - 66, y1: 196, x2: cx + 66, y2: 206 }
                ];
                for (let a of arcs) {
                    ctx.beginPath();
                    ctx.moveTo(a.x1, a.y1);
                    ctx.quadraticCurveTo((a.x1 + a.x2) / 2, Math.max(a.y1, a.y2) + 14, a.x2, a.y2);
                    ctx.stroke();
                }
            }

            // Baubles
            if (root.hasOrnament("baubles")) {
                const baubles = [
                    { x: cx - 12, y: 68, c: "#ef4444" },
                    { x: cx + 14, y: 76, c: "#facc15" },
                    { x: cx - 26, y: 108, c: "#38bdf8" },
                    { x: cx + 4,  y: 114, c: "#ef4444" },
                    { x: cx + 28, y: 118, c: "#f472b6" },
                    { x: cx - 40, y: 154, c: "#facc15" },
                    { x: cx - 10, y: 158, c: "#a855f7" },
                    { x: cx + 22, y: 152, c: "#ef4444" },
                    { x: cx + 44, y: 162, c: "#38bdf8" },
                    { x: cx - 52, y: 198, c: "#ef4444" },
                    { x: cx - 20, y: 202, c: "#facc15" },
                    { x: cx + 16, y: 198, c: "#38bdf8" },
                    { x: cx + 48, y: 202, c: "#f472b6" }
                ];
                for (let b of baubles) {
                    ctx.fillStyle = b.c;
                    ctx.beginPath();
                    ctx.arc(b.x, b.y, 5.5, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillStyle = "rgba(255,255,255,0.65)";
                    ctx.beginPath();
                    ctx.arc(b.x - 1.8, b.y - 1.8, 1.6, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            // Candy canes
            if (root.hasOrnament("candy_canes")) {
                const canes = [
                    { x: cx - 18, y: 132 },
                    { x: cx + 32, y: 178 },
                    { x: cx - 34, y: 182 }
                ];
                for (let c of canes) {
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 3.5;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(c.x, c.y + 14);
                    ctx.lineTo(c.x, c.y);
                    ctx.arc(c.x - 3.5, c.y, 3.5, 0, Math.PI, true);
                    ctx.stroke();
                    ctx.strokeStyle = "#ef4444";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(c.x, c.y + 10);
                    ctx.lineTo(c.x, c.y + 6);
                    ctx.moveTo(c.x, c.y + 2);
                    ctx.lineTo(c.x, c.y - 1);
                    ctx.stroke();
                }
            }

            // Bells
            if (root.hasOrnament("bells")) {
                const bells = [{ x: cx + 12, y: 96 }, { x: cx - 24, y: 142 }, { x: cx + 34, y: 192 }];
                for (let bl of bells) {
                    ctx.fillStyle = "#facc15";
                    ctx.beginPath();
                    ctx.moveTo(bl.x, bl.y - 5);
                    ctx.lineTo(bl.x + 5, bl.y + 4);
                    ctx.lineTo(bl.x - 5, bl.y + 4);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Gingerbread
            if (root.hasOrnament("gingerbread")) {
                const gbs = [{ x: cx - 4, y: 92 }, { x: cx + 18, y: 138 }, { x: cx - 36, y: 168 }];
                for (let gb of gbs) {
                    ctx.fillStyle = "#b45309";
                    ctx.beginPath();
                    ctx.arc(gb.x, gb.y - 4, 3.5, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillRect(gb.x - 3, gb.y - 1, 6, 7);
                    ctx.fillRect(gb.x - 6, gb.y, 12, 2.5);
                }
            }

            // Bows
            if (root.hasOrnament("bows")) {
                const bows = [{ x: cx + 18, y: 104 }, { x: cx - 16, y: 174 }, { x: cx + 4, y: 192 }];
                for (let bw of bows) {
                    ctx.fillStyle = "#ef4444";
                    ctx.beginPath();
                    ctx.moveTo(bw.x, bw.y);
                    ctx.lineTo(bw.x - 6, bw.y - 4);
                    ctx.lineTo(bw.x - 6, bw.y + 4);
                    ctx.closePath();
                    ctx.moveTo(bw.x, bw.y);
                    ctx.lineTo(bw.x + 6, bw.y - 4);
                    ctx.lineTo(bw.x + 6, bw.y + 4);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Mini stars
            if (root.hasOrnament("stars")) {
                const sts = [{ x: cx - 16, y: 84 }, { x: cx + 26, y: 134 }, { x: cx - 4, y: 146 }, { x: cx + 30, y: 196 }];
                ctx.fillStyle = "#fef08a";
                for (let st of sts) {
                    ctx.beginPath();
                    for (let k = 0; k < 10; k++) {
                        const r = (k % 2 === 0) ? 5 : 2.2;
                        const ang = -Math.PI / 2 + k * Math.PI / 5;
                        const px = st.x + Math.cos(ang) * r;
                        const py = st.y + Math.sin(ang) * r;
                        if (k === 0) ctx.moveTo(px, py);
                        else ctx.lineTo(px, py);
                    }
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Gifts at base
            if (root.showGifts) {
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.roundedRect(cx - 46, 218, 24, 20, 3, 3);
                ctx.fill();
                ctx.fillStyle = "#facc15";
                ctx.fillRect(cx - 36, 218, 4, 20);
                ctx.fillRect(cx - 46, 226, 24, 4);

                ctx.fillStyle = "#3b82f6";
                ctx.beginPath();
                ctx.roundedRect(cx + 22, 222, 22, 16, 3, 3);
                ctx.fill();
                ctx.fillStyle = "#f8fafc";
                ctx.fillRect(cx + 31, 222, 4, 16);
                ctx.fillRect(cx + 22, 228, 22, 4);
            }

            // Topper
            const ty = 22;
            if (root.topper === "star") {
                ctx.save();
                ctx.shadowColor = "#fde047";
                ctx.shadowBlur = 14;
                ctx.fillStyle = "#facc15";
                ctx.beginPath();
                for (let k = 0; k < 10; k++) {
                    const r = (k % 2 === 0) ? 15 : 6.5;
                    const ang = -Math.PI / 2 + k * Math.PI / 5;
                    const px = cx + Math.cos(ang) * r;
                    const py = ty + Math.sin(ang) * r;
                    if (k === 0) ctx.moveTo(px, py);
                    else ctx.lineTo(px, py);
                }
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            } else if (root.topper === "snowflake") {
                ctx.save();
                ctx.strokeStyle = "#bae6fd";
                ctx.shadowColor = "#7dd3fc";
                ctx.shadowBlur = 10;
                ctx.lineWidth = 2.4;
                for (let k = 0; k < 6; k++) {
                    const ang = k * Math.PI / 3;
                    ctx.beginPath();
                    ctx.moveTo(cx, ty);
                    ctx.lineTo(cx + Math.cos(ang) * 13, ty + Math.sin(ang) * 13);
                    ctx.stroke();
                }
                ctx.restore();
            } else if (root.topper === "bow") {
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.moveTo(cx, ty + 4);
                ctx.lineTo(cx - 14, ty - 6);
                ctx.lineTo(cx - 14, ty + 10);
                ctx.closePath();
                ctx.moveTo(cx, ty + 4);
                ctx.lineTo(cx + 14, ty - 6);
                ctx.lineTo(cx + 14, ty + 10);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = "#b91c1c";
                ctx.beginPath();
                ctx.arc(cx, ty + 4, 4, 0, Math.PI * 2);
                ctx.fill();
            } else if (root.topper === "bell") {
                ctx.fillStyle = "#facc15";
                ctx.beginPath();
                ctx.arc(cx, ty + 2, 9, Math.PI, 0);
                ctx.lineTo(cx + 12, ty + 12);
                ctx.lineTo(cx - 12, ty + 12);
                ctx.closePath();
                ctx.fill();
            } else if (root.topper === "heart") {
                ctx.fillStyle = "#f43f5e";
                ctx.beginPath();
                ctx.arc(cx - 5, ty, 6, 0, Math.PI * 2);
                ctx.arc(cx + 5, ty, 6, 0, Math.PI * 2);
                ctx.lineTo(cx, ty + 14);
                ctx.closePath();
                ctx.fill();
            } else if (root.topper === "spire") {
                ctx.fillStyle = "#facc15";
                ctx.beginPath();
                ctx.moveTo(cx, ty - 14);
                ctx.lineTo(cx + 6, ty + 10);
                ctx.lineTo(cx - 6, ty + 10);
                ctx.closePath();
                ctx.fill();
                ctx.beginPath();
                ctx.arc(cx, ty + 4, 7, 0, Math.PI * 2);
                ctx.fill();
            }

            ctx.restore();
        }
    }

    // Animated twinkling fairy lights overlay (GPU-composited, zero Canvas repaints)
    Item {
        id: lightsLayer
        anchors.fill: parent
        visible: root.hasOrnament("lights")

        property real phase: 0
        NumberAnimation on phase {
            from: 0; to: Math.PI * 2; duration: 2400; loops: Animation.Infinite
            running: lightsLayer.visible
        }

        readonly property var bulbs: [
            { rx: 0.46, ry: 0.24, c: "#fde047", p: 0.0 },
            { rx: 0.55, ry: 0.28, c: "#fb7185", p: 1.1 },
            { rx: 0.40, ry: 0.38, c: "#38bdf8", p: 2.2 },
            { rx: 0.52, ry: 0.41, c: "#fde047", p: 3.3 },
            { rx: 0.62, ry: 0.44, c: "#4ade80", p: 4.4 },
            { rx: 0.34, ry: 0.55, c: "#fb7185", p: 0.7 },
            { rx: 0.48, ry: 0.58, c: "#fde047", p: 1.9 },
            { rx: 0.64, ry: 0.60, c: "#38bdf8", p: 2.8 },
            { rx: 0.28, ry: 0.72, c: "#fde047", p: 3.9 },
            { rx: 0.44, ry: 0.75, c: "#4ade80", p: 5.0 },
            { rx: 0.58, ry: 0.74, c: "#fb7185", p: 1.4 },
            { rx: 0.72, ry: 0.76, c: "#fde047", p: 2.5 }
        ]

        Repeater {
            model: lightsLayer.bulbs
            delegate: Rectangle {
                required property var modelData
                readonly property real glow: 0.45 + 0.55 * Math.abs(Math.sin(lightsLayer.phase + modelData.p))
                x: root.width * modelData.rx - width / 2
                y: root.height * modelData.ry - height / 2
                width: Math.max(6, root.width * 0.045)
                height: width
                radius: width / 2
                color: modelData.c
                opacity: glow
                scale: 0.85 + 0.3 * glow
            }
        }
    }
}
