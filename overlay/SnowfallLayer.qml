import QtQuick
import Quickshell

Item {
    id: root

    required property bool active
    required property int snowMode
    required property int intensity
    required property var windowRects
    property real screenW: 0
    property real screenH: 0

    signal flakeLanded(real fx, real fy, string addr)
    signal chunkLanded(real cx, real cy, string addr)

    visible: active

    readonly property real effW: (screenW > 200) ? screenW : (root.width > 200 ? root.width : (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920))
    readonly property real effH: (screenH > 200) ? screenH : (root.height > 200 ? root.height : (Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080))

    readonly property int maxFlakes: 200
    readonly property int activeCount: Math.max(50, Math.min(maxFlakes, Math.round((intensity / 100.0) * maxFlakes)))
    readonly property int maxChunks: 64

    property real windTime: 0
    property real windVel: 0
    property var flakes: []
    property var chunks: []

    function resetParticle(f, w, h, startAnywhere) {
        const depth = 0.22 + Math.random() * 0.78;
        f.depth = depth;
        f.x = 16 + Math.random() * Math.max(100, w - 32);
        f.y = startAnywhere ? (Math.random() * h) : (-16 - Math.random() * 32);
        f.phase1 = Math.random() * Math.PI * 2;
        f.phase2 = Math.random() * Math.PI * 2;
        f.swayFreq1 = 0.8 + Math.random() * 1.5;
        f.swayFreq2 = 1.3 + Math.random() * 1.8;
        f.speedJitter = 0.85 + Math.random() * 0.35;
        f.windSens = 0.35 + (1.0 - depth) * 0.65;
        f.rot = Math.random() * 360;
        f.rotSpeed = (Math.random() - 0.5) * 80;
        f.size = 2.0 + depth * 2.8;
        f.alpha = 0.40 + depth * 0.55;
    }

    function initPools() {
        const w = effW;
        const h = effH;
        const arr = [];
        const count = Math.max(1, activeCount);
        const binW = Math.max(6, (w - 32) / count);
        for (let i = 0; i < maxFlakes; i++) {
            const f = { index: i };
            resetParticle(f, w, h, true);
            // Stratified placement by activeCount guarantees 100% full-screen coverage at ANY intensity
            f.x = 16 + ((i % count) + Math.random() * 0.95) * binW;
            if (f.x > w - 16) f.x = 16 + Math.random() * (w - 32);
            arr.push(f);
        }
        flakes = arr;

        const ch = [];
        for (let i = 0; i < maxChunks; i++) {
            ch.push({
                active: false,
                x: 0, y: 0, vx: 0, vy: 0,
                size: 5, alpha: 0.9, age: 0,
                ignoreAddr: ""
            });
        }
        chunks = ch;
    }

    onActiveCountChanged: {
        if (flakes.length > 0 && effW > 200) {
            const count = Math.max(1, activeCount);
            const binW = Math.max(6, (effW - 32) / count);
            for (let i = 0; i < flakes.length; i++) {
                flakes[i].x = 16 + ((i % count) + Math.random() * 0.95) * binW;
            }
        }
    }

    onEffWChanged: {
        if (flakes.length > 0 && effW > 200) {
            const count = Math.max(1, activeCount);
            const binW = Math.max(6, (effW - 32) / count);
            for (let i = 0; i < flakes.length; i++) {
                flakes[i].x = 16 + ((i % count) + Math.random() * 0.95) * binW;
            }
        }
    }

    // Spawn flying snow chunks when a window is dragged fast, thrown, or closed!
    function spawnSnowChunks(startX, startY, spanW, vx, vy, count, ignoreAddr) {
        if (!root.visible || chunks.length === 0) return;
        let spawned = 0;
        for (let i = 0; i < maxChunks && spawned < count; i++) {
            const c = chunks[i];
            if (!c.active) {
                const t = (spawned + 0.5) / Math.max(1, count);
                c.active = true;
                c.x = startX + t * Math.max(20, spanW) + (Math.random() - 0.5) * 16;
                c.y = startY - 2 - Math.random() * 6;
                c.vx = vx * (0.72 + Math.random() * 0.45) + (Math.random() - 0.5) * 130;
                c.vy = vy * 0.55 - (65 + Math.random() * 140);
                c.size = 3.8 + Math.random() * 4.2;
                c.alpha = 0.85 + Math.random() * 0.15;
                c.age = 0;
                c.ignoreAddr = ignoreAddr || "";
                spawned += 1;
            }
        }
    }

    Component.onCompleted: initPools()

    // True 144Hz VSync FrameAnimation locked to Wayland compositor refresh!
    FrameAnimation {
        running: root.visible && root.effW > 0 && root.effH > 0
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.001, frameTime));
            root.windTime += dt;
            root.windVel = Math.sin(root.windTime * 0.38) * 20 + Math.sin(root.windTime * 0.14) * 11;

            const w = root.effW;
            const h = root.effH;
            const cnt = root.activeCount;
            const wrs = root.windowRects || [];
            const mode = root.snowMode;

            // 1. Step falling particles dynamically styled for each season at 144Hz
            for (let i = 0; i < cnt; i++) {
                const f = root.flakes[i];
                const prevY = f.y;

                f.phase1 += f.swayFreq1 * dt;
                f.phase2 += f.swayFreq2 * dt;

                let vy, sway, flutterVy;
                if (mode === 2) {
                    // RAIN: fast downward velocity, minimal horizontal flutter
                    vy = (460 + f.depth * 280) * f.speedJitter;
                    sway = 0;
                    flutterVy = 0;
                } else if (mode === 1) {
                    // AUTUMN LEAVES: tumbling, floating in the wind
                    vy = (44 + f.depth * 42) * f.speedJitter;
                    sway = Math.sin(f.phase1) * (12 + f.depth * 22) + Math.cos(f.phase2) * (8 + f.depth * 14);
                    flutterVy = Math.sin(f.phase1 * 1.5) * (vy * 0.12);
                } else if (mode === 3) {
                    // CHERRY BLOSSOM: gentle floating drift
                    vy = (34 + f.depth * 36) * f.speedJitter;
                    sway = Math.sin(f.phase1) * (10 + f.depth * 18) + Math.cos(f.phase2) * (6 + f.depth * 12);
                    flutterVy = Math.sin(f.phase1 * 1.5) * (vy * 0.10);
                } else {
                    // SNOW: peaceful fluttering snowflakes
                    vy = (38 + f.depth * 44) * f.speedJitter;
                    sway = Math.sin(f.phase1) * (5 + f.depth * 14) + Math.cos(f.phase2) * (3 + f.depth * 9);
                    flutterVy = Math.sin(f.phase1 * 1.5) * (vy * 0.08);
                }

                f.x += (f.vx + root.windVel * f.windSens + sway) * dt;
                f.y += (vy + flutterVy) * dt;
                f.rot = (f.rot + f.rotSpeed * dt) % 360;

                if (f.x < 10) f.x = w - 14;
                else if (f.x > w - 12) f.x = 14;

                let landed = false;

                if (f.depth > 0.40) {
                    for (let j = 0; j < wrs.length; j++) {
                        const wr = wrs[j];
                        if (wr.w > 80 && wr.y > 24 && f.x >= wr.x + 8 && f.x <= wr.x + wr.w - 8) {
                            if (prevY <= wr.y && f.y >= wr.y) {
                                let covered = false;
                                for (let k = 0; k < wrs.length; k++) {
                                    if (k === j) continue;
                                    const o = wrs[k];
                                    if (f.x >= o.x && f.x <= o.x + o.w && o.y <= wr.y && o.y + o.h >= wr.y - 4) {
                                        covered = true;
                                        break;
                                    }
                                }
                                if (!covered) {
                                    root.flakeLanded(f.x, wr.y, wr.addr);
                                    landed = true;
                                    break;
                                }
                            }
                        }
                    }
                }

                if (!landed && f.y >= h - 2) {
                    root.flakeLanded(f.x, h, "");
                    landed = true;
                }

                if (landed) {
                    root.resetParticle(f, w, h, false);
                }

                const item = flakeRep.itemAt(i);
                if (item) {
                    item.pX = f.x;
                    item.pY = f.y;
                    item.opacity = f.alpha;
                    if (mode !== 2) item.rotation = f.rot;
                }
            }

            // 2. Step flying chunks at 144Hz
            for (let i = 0; i < root.maxChunks; i++) {
                const c = root.chunks[i];
                const cItem = chunkRep.itemAt(i);
                if (!c.active) {
                    if (cItem && cItem.visible) cItem.visible = false;
                    continue;
                }

                const prevY = c.y;
                c.age += dt;
                c.vy += 1150 * dt;
                c.vx *= (1.0 - 0.35 * dt);
                c.x += c.vx * dt;
                c.y += c.vy * dt;

                if (c.x < 14) { c.x = 14; c.vx = Math.abs(c.vx) * 0.4; }
                else if (c.x > w - 14) { c.x = w - 14; c.vx = -Math.abs(c.vx) * 0.4; }

                let hit = false;
                if (c.vy > 0) {
                    for (let j = 0; j < wrs.length; j++) {
                        const wr = wrs[j];
                        if (wr.addr === c.ignoreAddr && c.age < 0.22) continue;
                        if (wr.w > 80 && wr.y > 24 && c.x >= wr.x + 8 && c.x <= wr.x + wr.w - 8) {
                            if (prevY <= wr.y + 6 && c.y >= wr.y) {
                                root.chunkLanded(c.x, wr.y, wr.addr);
                                hit = true;
                                break;
                            }
                        }
                    }
                }

                if (!hit && c.y >= h - 2) {
                    root.chunkLanded(c.x, h, "");
                    hit = true;
                }

                if (hit || c.age > 3.5) {
                    c.active = false;
                    if (cItem) cItem.visible = false;
                } else if (cItem) {
                    cItem.visible = true;
                    cItem.x = c.x - c.size / 2;
                    cItem.y = c.y - c.size / 2;
                    cItem.width = c.size;
                    cItem.height = c.size;
                    cItem.opacity = c.alpha;
                }
            }
        }
    }

    Repeater {
        id: flakeRep
        model: root.maxFlakes
        delegate: Item {
            id: flakeItem
            required property int index
            readonly property var fData: (index < root.flakes.length) ? root.flakes[index] : null
            readonly property real pDepth: fData ? fData.depth : 0.5
            readonly property real pSize: fData ? fData.size : 3.0
            property real pX: fData ? fData.x : (16 + index * 9.5)
            property real pY: fData ? fData.y : -20

            x: pX - width / 2
            y: pY - height / 2

            visible: fData !== null && index < root.activeCount
            width: (root.snowMode === 2) ? 2 : ((root.snowMode === 1) ? 20 : ((root.snowMode === 3) ? 16 : (index % 12 === 0 ? 12 : pSize)))
            height: (root.snowMode === 2) ? Math.max(14, 12 + pDepth * 14) : width

            // 1. MODE 0: Snow dot (round white powdery flake)
            Rectangle {
                visible: root.snowMode === 0 && (index % 12 !== 0)
                anchors.centerIn: parent
                width: flakeItem.pSize
                height: width
                radius: width / 2
                color: "#ffffff"
            }

            // 2. MODE 0: Snow crystal star (❄)
            Text {
                visible: root.snowMode === 0 && (index % 12 === 0)
                anchors.centerIn: parent
                text: "❄"
                color: "#e0f2fe"
                font.pixelSize: Math.max(8, 6.0 + flakeItem.pDepth * 3.5)
            }

            // 3. MODE 1: Autumn Leaves ("Relief") - vibrant autumn leaves (🍁, 🍂, 🍃)
            Text {
                visible: root.snowMode === 1
                anchors.centerIn: parent
                text: (index % 3 === 0) ? "🍁" : ((index % 3 === 1) ? "🍂" : "🍃")
                color: ["#ef4444", "#f97316", "#eab308", "#d97706", "#dc2626", "#b45309"][index % 6]
                font.pixelSize: Math.max(11, 10.0 + flakeItem.pDepth * 7.5)
            }

            // 4. MODE 2: Rain - sleek fast rain streaks tilted with wind
            Rectangle {
                visible: root.snowMode === 2
                anchors.centerIn: parent
                width: 1.8
                height: Math.max(14, 12 + flakeItem.pDepth * 14)
                radius: 0.9
                color: "#7dd3fc"
                opacity: 0.85
                rotation: root.windVel * 0.45
            }

            // 5. MODE 3: Cherry Blossom - soft pink sakura petals (🌸)
            Text {
                visible: root.snowMode === 3
                anchors.centerIn: parent
                text: "🌸"
                color: ["#fbcfe8", "#f472b6", "#fda4af", "#f43f5e", "#fce7f3"][index % 5]
                font.pixelSize: Math.max(10, 9.0 + flakeItem.pDepth * 5.5)
            }
        }
    }

    Repeater {
        id: chunkRep
        model: root.maxChunks
        delegate: Rectangle {
            visible: false
            width: 5
            height: 5
            radius: width / 2
            color: (root.snowMode === 1) ? "#f97316" : ((root.snowMode === 3) ? "#fbcfe8" : ((root.snowMode === 2) ? "#7dd3fc" : "#f8fafc"))
            border.color: (root.snowMode === 1) ? "#d97706" : "#e0f2fe"
            border.width: 0.5
        }
    }
}
