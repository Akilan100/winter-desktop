import QtQuick

Canvas {
    id: canvas

    property string hat: "tophat"
    property string face: "happy"
    property string body: "mittens"
    property string clothes: "scarf"
    property real lookX: 0.0 // -1..1 subtle eye tracking
    property real lookY: 0.0
    property bool blinking: false

    onHatChanged: requestPaint()
    onFaceChanged: requestPaint()
    onBodyChanged: requestPaint()
    onClothesChanged: requestPaint()
    onLookXChanged: requestPaint()
    onLookYChanged: requestPaint()
    onBlinkingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        if (w <= 0 || h <= 0) return;
        ctx.clearRect(0, 0, w, h);

        ctx.save();
        const s = Math.min(w / 160.0, h / 200.0);
        ctx.translate((w - 160 * s) / 2, (h - 200 * s) / 2);
        ctx.scale(s, s);

        const cx = 80;

        // Soft ground shadow
        ctx.save();
        const shGrad = ctx.createRadialGradient(cx, 186, 4, cx, 186, 44);
        shGrad.addColorStop(0, "rgba(15, 23, 42, 0.38)");
        shGrad.addColorStop(1, "rgba(15, 23, 42, 0.0)");
        ctx.fillStyle = shGrad;
        ctx.beginPath();
        ctx.ellipse(cx - 44, 176, 88, 20);
        ctx.fill();
        ctx.restore();

        // Helper for 3D snow sphere
        function drawSnowBall(x, y, r) {
            ctx.save();
            ctx.shadowColor = "rgba(15, 23, 42, 0.22)";
            ctx.shadowBlur = 8;
            ctx.shadowOffsetY = 3;
            const g = ctx.createRadialGradient(x - r * 0.32, y - r * 0.32, r * 0.1, x, y, r);
            g.addColorStop(0, "#ffffff");
            g.addColorStop(0.65, "#f1f5f9");
            g.addColorStop(1, "#cbd5e1");
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // Subtle icy rim
            ctx.strokeStyle = "rgba(255, 255, 255, 0.85)";
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.arc(x, y, r - 0.6, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Bottom, middle, head spheres
        drawSnowBall(cx, 150, 36);
        drawSnowBall(cx, 104, 27);
        drawSnowBall(cx, 64, 21);

        // Coal buttons on torso (unless covered by sweater/tuxedo/puffer)
        if (clothes !== "sweater" && clothes !== "puffer" && clothes !== "tuxedo") {
            ctx.fillStyle = "#1e293b";
            for (let i = 0; i < 3; i++) {
                ctx.beginPath();
                ctx.arc(cx, 96 + i * 11, 2.6, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Clothes layer (on torso & neck)
        if (clothes === "sweater") {
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, 104, 26.5, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = "#dc2626";
            ctx.fillRect(cx - 30, 82, 60, 48);
            // Festive white zigzag pattern
            ctx.strokeStyle = "#fef2f2";
            ctx.lineWidth = 2.2;
            ctx.beginPath();
            for (let x = cx - 28; x <= cx + 28; x += 8) {
                ctx.lineTo(x, (Math.floor((x - cx) / 8) % 2 === 0) ? 96 : 102);
            }
            ctx.stroke();
            // Snowflake dot
            ctx.fillStyle = "#fde047";
            ctx.beginPath();
            ctx.arc(cx, 112, 3, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        } else if (clothes === "puffer") {
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, 104, 26.5, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = "#2563eb";
            ctx.fillRect(cx - 28, 82, 56, 48);
            ctx.strokeStyle = "#1d4ed8";
            ctx.lineWidth = 2;
            for (let y = 90; y <= 122; y += 8) {
                ctx.beginPath();
                ctx.moveTo(cx - 28, y);
                ctx.lineTo(cx + 28, y);
                ctx.stroke();
            }
            ctx.strokeStyle = "#e2e8f0";
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(cx, 82);
            ctx.lineTo(cx, 130);
            ctx.stroke();
            ctx.restore();
        } else if (clothes === "tuxedo") {
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, 104, 26.5, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = "#0f172a";
            ctx.fillRect(cx - 28, 82, 56, 48);
            // White shirt V
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.moveTo(cx - 10, 82);
            ctx.lineTo(cx + 10, 82);
            ctx.lineTo(cx, 116);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
            ctx.strokeStyle = "rgba(255, 255, 255, 0.28)";
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.arc(cx, 104, 26.5, 0.2, Math.PI - 0.2);
            ctx.stroke();
            // Red bow tie
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.moveTo(cx, 85);
            ctx.lineTo(cx - 9, 80);
            ctx.lineTo(cx - 9, 90);
            ctx.closePath();
            ctx.moveTo(cx, 85);
            ctx.lineTo(cx + 9, 80);
            ctx.lineTo(cx + 9, 90);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx, 85, 2.5, 0, Math.PI * 2);
            ctx.fill();
        } else if (clothes === "tie") {
            ctx.fillStyle = "#0f172a";
            ctx.beginPath();
            ctx.moveTo(cx - 4, 84);
            ctx.lineTo(cx + 4, 84);
            ctx.lineTo(cx + 5, 112);
            ctx.lineTo(cx, 118);
            ctx.lineTo(cx - 5, 112);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#334155";
            ctx.beginPath();
            ctx.arc(cx, 84, 3.5, 0, Math.PI * 2);
            ctx.fill();
        } else if (clothes === "bowtie") {
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.moveTo(cx, 84);
            ctx.lineTo(cx - 11, 78);
            ctx.lineTo(cx - 11, 90);
            ctx.closePath();
            ctx.moveTo(cx, 84);
            ctx.lineTo(cx + 11, 78);
            ctx.lineTo(cx + 11, 90);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#b91c1c";
            ctx.beginPath();
            ctx.arc(cx, 84, 3, 0, Math.PI * 2);
            ctx.fill();
        } else if (clothes === "gold_chain") {
            ctx.strokeStyle = "#facc15";
            ctx.lineWidth = 3.2;
            ctx.beginPath();
            ctx.arc(cx, 82, 14, 0.2, Math.PI - 0.2);
            ctx.stroke();
            ctx.fillStyle = "#eab308";
            ctx.beginPath();
            ctx.arc(cx, 98, 5, 0, Math.PI * 2);
            ctx.fill();
            ctx.strokeStyle = "#fef08a";
            ctx.lineWidth = 1;
            ctx.stroke();
        } else if (clothes === "scarf" || clothes === "striped_scarf") {
            // Trailing tail
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.roundedRect(cx + 4, 82, 11, 28, 4, 4);
            ctx.fill();
            // Neck wrap
            ctx.beginPath();
            ctx.roundedRect(cx - 20, 78, 40, 10, 5, 5);
            ctx.fill();
            if (clothes === "striped_scarf") {
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(cx - 12, 78, 5, 10);
                ctx.fillRect(cx + 2, 78, 5, 10);
                ctx.fillRect(cx + 4, 92, 11, 4);
                ctx.fillRect(cx + 4, 101, 11, 4);
            }
        }

        // Arms / Body accessories
        function drawTwigArm(x1, y1, x2, y2, x3, y3) {
            ctx.strokeStyle = "#78350f";
            ctx.lineWidth = 3.2;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            ctx.lineTo(x3, y3);
            ctx.stroke();
        }

        if (body === "waving") {
            drawTwigArm(cx - 24, 98, cx - 44, 86, cx - 50, 72);
            drawTwigArm(cx + 24, 98, cx + 44, 78, cx + 50, 62);
        } else {
            drawTwigArm(cx - 24, 98, cx - 44, 90, cx - 52, 82);
            drawTwigArm(cx + 24, 98, cx + 44, 90, cx + 52, 82);
        }

        if (body === "mittens") {
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.arc(cx - 52, 82, 6, 0, Math.PI * 2);
            ctx.arc(cx + 52, 82, 6, 0, Math.PI * 2);
            ctx.fill();
        } else if (body === "broom") {
            ctx.strokeStyle = "#92400e";
            ctx.lineWidth = 3.5;
            ctx.beginPath();
            ctx.moveTo(cx + 48, 48);
            ctx.lineTo(cx + 56, 168);
            ctx.stroke();
            ctx.fillStyle = "#d97706";
            ctx.beginPath();
            ctx.moveTo(cx + 48, 156);
            ctx.lineTo(cx + 64, 156);
            ctx.lineTo(cx + 68, 178);
            ctx.lineTo(cx + 44, 178);
            ctx.closePath();
            ctx.fill();
        } else if (body === "candycane") {
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 5;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(cx + 52, 112);
            ctx.lineTo(cx + 52, 72);
            ctx.arc(cx + 46, 72, 6, 0, Math.PI, true);
            ctx.stroke();
            ctx.strokeStyle = "#ef4444";
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(cx + 52, 104);
            ctx.lineTo(cx + 52, 96);
            ctx.moveTo(cx + 52, 88);
            ctx.lineTo(cx + 52, 80);
            ctx.stroke();
        } else if (body === "cocoa") {
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.roundedRect(cx + 44, 74, 16, 16, 3, 3);
            ctx.fill();
            ctx.fillStyle = "#78350f";
            ctx.fillRect(cx + 46, 75, 12, 3);
            ctx.strokeStyle = "rgba(255,255,255,0.75)";
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(cx + 49, 71);
            ctx.quadraticCurveTo(cx + 46, 65, cx + 50, 60);
            ctx.moveTo(cx + 55, 71);
            ctx.quadraticCurveTo(cx + 58, 65, cx + 54, 60);
            ctx.stroke();
        } else if (body === "gift") {
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.roundedRect(cx + 42, 72, 20, 18, 3, 3);
            ctx.fill();
            ctx.fillStyle = "#facc15";
            ctx.fillRect(cx + 50, 72, 4, 18);
            ctx.fillRect(cx + 42, 79, 20, 4);
        } else if (body === "flowers") {
            ctx.strokeStyle = "#16a34a";
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(cx + 52, 86);
            ctx.lineTo(cx + 52, 68);
            ctx.stroke();
            const cols = ["#f43f5e", "#facc15", "#a855f7"];
            for (let i = 0; i < 3; i++) {
                ctx.fillStyle = cols[i];
                ctx.beginPath();
                ctx.arc(cx + 47 + i * 5, 66 + (i % 2) * 4, 4.5, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Face
        const ex = lookX * 1.8;
        const ey = lookY * 1.4;

        // Rosy cheeks for happy/love/classic
        if (face === "happy" || face === "love" || face === "classic") {
            ctx.fillStyle = "rgba(251, 113, 133, 0.45)";
            ctx.beginPath();
            ctx.arc(cx - 11, 66, 3.5, 0, Math.PI * 2);
            ctx.arc(cx + 11, 66, 3.5, 0, Math.PI * 2);
            ctx.fill();
        }

        // Eyes
        ctx.fillStyle = "#0f172a";
        ctx.strokeStyle = "#0f172a";
        ctx.lineWidth = 2;
        if (face === "cool") {
            // Sunglasses
            ctx.fillStyle = "#0f172a";
            ctx.beginPath();
            ctx.roundedRect(cx - 15, 54, 13, 8, 2, 2);
            ctx.roundedRect(cx + 2, 54, 13, 8, 2, 2);
            ctx.fill();
            ctx.fillRect(cx - 2, 56, 4, 2);
            ctx.fillStyle = "rgba(255,255,255,0.35)";
            ctx.fillRect(cx - 13, 55, 4, 2);
            ctx.fillRect(cx + 4, 55, 4, 2);
        } else if (face === "love") {
            ctx.fillStyle = "#e11d48";
            for (let side of [-7, 7]) {
                ctx.beginPath();
                ctx.arc(cx + side - 1.8, 57, 2.2, 0, Math.PI * 2);
                ctx.arc(cx + side + 1.8, 57, 2.2, 0, Math.PI * 2);
                ctx.lineTo(cx + side, 62);
                ctx.fill();
            }
        } else if (face === "sleepy" || blinking) {
            ctx.beginPath();
            ctx.arc(cx - 7, 58, 3, 0, Math.PI);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx + 7, 58, 3, 0, Math.PI);
            ctx.stroke();
        } else if (face === "wink") {
            ctx.beginPath();
            ctx.arc(cx - 7 + ex, 58 + ey, 2.6, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx + 7, 58, 3, Math.PI, 0);
            ctx.stroke();
        } else {
            const rEye = (face === "surprised") ? 3.3 : 2.6;
            ctx.beginPath();
            ctx.arc(cx - 7 + ex, 58 + ey, rEye, 0, Math.PI * 2);
            ctx.arc(cx + 7 + ex, 58 + ey, rEye, 0, Math.PI * 2);
            ctx.fill();
            // Eye sparkle
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(cx - 7.8 + ex, 57 + ey, 0.9, 0, Math.PI * 2);
            ctx.arc(cx + 6.2 + ex, 57 + ey, 0.9, 0, Math.PI * 2);
            ctx.fill();
            if (face === "grumpy") {
                ctx.strokeStyle = "#0f172a";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(cx - 11, 52);
                ctx.lineTo(cx - 4, 55);
                ctx.moveTo(cx + 11, 52);
                ctx.lineTo(cx + 4, 55);
                ctx.stroke();
            }
        }

        // Carrot nose
        ctx.fillStyle = "#f97316";
        ctx.beginPath();
        ctx.moveTo(cx, 61);
        ctx.lineTo(cx + 13, 64);
        ctx.lineTo(cx, 66);
        ctx.closePath();
        ctx.fill();

        // Mouth
        ctx.strokeStyle = "#0f172a";
        ctx.fillStyle = "#0f172a";
        ctx.lineWidth = 2;
        if (face === "surprised") {
            ctx.beginPath();
            ctx.arc(cx, 72, 3.2, 0, Math.PI * 2);
            ctx.stroke();
        } else if (face === "grumpy") {
            ctx.beginPath();
            ctx.arc(cx, 75, 6, Math.PI + 0.4, -0.4);
            ctx.stroke();
        } else if (face === "happy" || face === "love") {
            ctx.beginPath();
            ctx.arc(cx, 69, 7, 0.2, Math.PI - 0.2);
            ctx.stroke();
        } else {
            // Coal dots smile
            for (let a = -2; a <= 2; a++) {
                ctx.beginPath();
                ctx.arc(cx + a * 3.2, 72 - Math.abs(a) * 0.7, 1.3, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Hats
        if (hat === "tophat") {
            ctx.fillStyle = "#0f172a";
            ctx.strokeStyle = "rgba(255, 255, 255, 0.32)";
            ctx.lineWidth = 1.1;
            ctx.beginPath();
            ctx.roundedRect(cx - 22, 42, 44, 5, 2.5, 2.5);
            ctx.fill();
            ctx.stroke();
            ctx.beginPath();
            ctx.roundedRect(cx - 14, 20, 28, 24, 3, 3);
            ctx.fill();
            ctx.stroke();
            ctx.fillStyle = "#ef4444";
            ctx.fillRect(cx - 14, 37, 28, 5);
        } else if (hat === "bobble") {
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.arc(cx, 44, 18, Math.PI, 0);
            ctx.fill();
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.roundedRect(cx - 19, 40, 38, 7, 3.5, 3.5);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx, 23, 6, 0, Math.PI * 2);
            ctx.fill();
        } else if (hat === "santa") {
            ctx.fillStyle = "#dc2626";
            ctx.beginPath();
            ctx.moveTo(cx - 18, 44);
            ctx.quadraticCurveTo(cx - 4, 16, cx + 18, 30);
            ctx.lineTo(cx + 16, 44);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.roundedRect(cx - 20, 40, 38, 7, 3.5, 3.5);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx + 19, 31, 5.5, 0, Math.PI * 2);
            ctx.fill();
        } else if (hat === "crown") {
            ctx.fillStyle = "#facc15";
            ctx.beginPath();
            ctx.moveTo(cx - 14, 44);
            ctx.lineTo(cx - 16, 26);
            ctx.lineTo(cx - 7, 35);
            ctx.lineTo(cx, 22);
            ctx.lineTo(cx + 7, 35);
            ctx.lineTo(cx + 16, 26);
            ctx.lineTo(cx + 14, 44);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.arc(cx, 38, 2.5, 0, Math.PI * 2);
            ctx.fill();
        } else if (hat === "cowboy") {
            ctx.fillStyle = "#92400e";
            ctx.beginPath();
            ctx.ellipse(cx - 24, 41, 48, 8);
            ctx.fill();
            ctx.beginPath();
            ctx.roundedRect(cx - 14, 24, 28, 18, 6, 6);
            ctx.fill();
            ctx.fillStyle = "#f59e0b";
            ctx.fillRect(cx - 14, 36, 28, 4);
        } else if (hat === "party") {
            ctx.fillStyle = "#8b5cf6";
            ctx.beginPath();
            ctx.moveTo(cx - 13, 44);
            ctx.lineTo(cx, 16);
            ctx.lineTo(cx + 13, 44);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#facc15";
            ctx.beginPath();
            ctx.arc(cx, 16, 4.5, 0, Math.PI * 2);
            ctx.fill();
        } else if (hat === "earmuffs") {
            ctx.strokeStyle = "#1e293b";
            ctx.lineWidth = 3.5;
            ctx.beginPath();
            ctx.arc(cx, 60, 22, Math.PI + 0.2, -0.2);
            ctx.stroke();
            ctx.fillStyle = "#ef4444";
            ctx.beginPath();
            ctx.arc(cx - 21, 62, 7, 0, Math.PI * 2);
            ctx.arc(cx + 21, 62, 7, 0, Math.PI * 2);
            ctx.fill();
        }

        ctx.restore();
    }
}
