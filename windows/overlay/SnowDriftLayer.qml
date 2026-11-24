import QtQuick

Item {
    id: root

    required property var groundBuckets
    required property var windowRects
    required property var windowBucketsMap
    required property int snowMode

    visible: true

    function paintStrip(ctx, w, h, buckets, maxH) {
        ctx.clearRect(0, 0, w, h);
        if (!buckets || buckets.length < 2 || w <= 20) return;
        let hasAny = false;
        for (let i = 0; i < buckets.length; i++) {
            if (buckets[i] > 0.02) { hasAny = true; break; }
        }
        if (!hasAny) return;

        const n = buckets.length;
        const step = w / (n - 1);

        // 1. Moving-average smoothing pass across raw buckets to ensure a velvety smooth contour
        const smoothed = new Array(n);
        for (let i = 0; i < n; i++) {
            let sum = 0, count = 0;
            for (let j = Math.max(0, i - 2); j <= Math.min(n - 1, i + 2); j++) {
                const weight = (j === i) ? 1.0 : (Math.abs(j - i) === 1 ? 0.70 : 0.35);
                sum += (buckets[j] || 0) * weight;
                count += weight;
            }
            smoothed[i] = sum / count;
        }

        // 2. Generate smooth points with natural corner edge taper
        const pts = [];
        for (let i = 0; i < n; i++) {
            const d = Math.max(0, Math.min(1.0, smoothed[i]));
            const edgeFade = (i === 0 || i === n - 1) ? 0.0 : ((i === 1 || i === n - 2) ? 0.58 : 1.0);
            pts.push({ x: i * step, y: h - d * maxH * edgeFade });
        }

        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, h);
        ctx.lineTo(pts[0].x, pts[0].y);

        // 3. Catmull-Rom to Cubic Bézier Spline for mathematically smooth C1 wave curvature
        for (let i = 0; i < pts.length - 1; i++) {
            const p0 = (i > 0) ? pts[i - 1] : pts[i];
            const p1 = pts[i];
            const p2 = pts[i + 1];
            const p3 = (i < pts.length - 2) ? pts[i + 2] : p2;

            const cp1x = p1.x + (p2.x - p0.x) / 6.0;
            const cp1y = p1.y + (p2.y - p0.y) / 6.0;
            const cp2x = p2.x - (p3.x - p1.x) / 6.0;
            const cp2y = p2.y - (p3.y - p1.y) / 6.0;

            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
        }

        ctx.lineTo(w, h);
        ctx.closePath();

        // Seasonal wave gradient: Snow, Autumn Leaves, Rain, or Cherry Blossom
        const grad = ctx.createLinearGradient(0, h - maxH, 0, h);
        let crestColor = "rgba(255, 255, 255, 0.98)";
        if (root.snowMode === 1) { // Autumn Leaves
            grad.addColorStop(0.0, "rgba(251, 146, 60, 0.95)");
            grad.addColorStop(0.35, "rgba(217, 119, 6, 0.92)");
            grad.addColorStop(0.75, "rgba(180, 83, 9, 0.88)");
            grad.addColorStop(1.0, "rgba(120, 53, 15, 0.82)");
            crestColor = "rgba(254, 215, 170, 0.95)";
        } else if (root.snowMode === 2) { // Rain (glossy water sheen)
            grad.addColorStop(0.0, "rgba(224, 242, 254, 0.65)");
            grad.addColorStop(0.50, "rgba(186, 230, 253, 0.48)");
            grad.addColorStop(0.80, "rgba(125, 211, 252, 0.35)");
            grad.addColorStop(1.0, "rgba(56, 189, 248, 0.22)");
            crestColor = "rgba(240, 249, 255, 0.85)";
        } else if (root.snowMode === 3) { // Cherry Blossom (sakura petal carpet)
            grad.addColorStop(0.0, "rgba(253, 242, 248, 0.96)");
            grad.addColorStop(0.35, "rgba(251, 207, 232, 0.92)");
            grad.addColorStop(0.75, "rgba(244, 114, 182, 0.86)");
            grad.addColorStop(1.0, "rgba(219, 39, 119, 0.80)");
            crestColor = "rgba(255, 255, 255, 0.95)";
        } else { // Snow
            grad.addColorStop(0.0, "rgba(255, 255, 255, 0.98)");
            grad.addColorStop(0.35, "rgba(248, 250, 252, 0.95)");
            grad.addColorStop(0.75, "rgba(235, 243, 254, 0.92)");
            grad.addColorStop(1.0, "rgba(205, 225, 250, 0.88)");
            crestColor = "rgba(255, 255, 255, 0.98)";
        }
        ctx.fillStyle = grad;
        ctx.fill();

        // Illuminated wave crest stroke
        ctx.strokeStyle = crestColor;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(pts[0].x, pts[0].y);
        for (let i = 0; i < pts.length - 1; i++) {
            const p0 = (i > 0) ? pts[i - 1] : pts[i];
            const p1 = pts[i];
            const p2 = pts[i + 1];
            const p3 = (i < pts.length - 2) ? pts[i + 2] : p2;

            const cp1x = p1.x + (p2.x - p0.x) / 6.0;
            const cp1y = p1.y + (p2.y - p0.y) / 6.0;
            const cp2x = p2.x - (p3.x - p1.x) / 6.0;
            const cp2y = p2.y - (p3.y - p1.y) / 6.0;

            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
        }
        ctx.stroke();
        ctx.restore();
    }

    // 1. Lightweight 30px-tall bottom snow wave strip
    Canvas {
        id: groundCanvas
        x: 64
        y: Math.max(0, root.height - 28)
        width: Math.max(100, root.width - 74)
        height: 28
        property var b: root.groundBuckets
        property int m: root.snowMode
        onBChanged: requestPaint()
        onMChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: root.paintStrip(getContext("2d"), width, height, b, 24)
    }

    // 2. Lightweight per-window 18px-tall snow wave strips (GPU x/y moves at 144Hz with ZERO repaints!)
    Repeater {
        id: winDriftRep
        model: 6
        delegate: Item {
            id: wDrift
            required property int index
            readonly property var wr: (root.windowRects && index < root.windowRects.length) ? root.windowRects[index] : null
            readonly property var buckets: (wr && root.windowBucketsMap) ? root.windowBucketsMap[wr.addr] : null
            visible: wr !== null && buckets !== undefined && buckets !== null && wr.w > 80 && wr.y > 24
            x: wr ? (wr.x + 10) : 0
            y: wr ? (wr.y - 17) : 0
            width: wr ? Math.max(0, wr.w - 20) : 0
            height: 18

            Canvas {
                id: wCanvas
                anchors.fill: parent
                property var b: wDrift.buckets
                property int m: root.snowMode
                onBChanged: requestPaint()
                onMChanged: requestPaint()
                onWidthChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: root.paintStrip(getContext("2d"), width, height, b, 14)
            }
        }
    }
}
