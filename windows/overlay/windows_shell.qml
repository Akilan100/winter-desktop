import QtQuick
import QtQuick.Window

Window {
    id: win
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.SubWindow
    color: "transparent"

    width: Screen.width
    height: Screen.height
    x: 0
    y: 0

    property bool hasFullscreen: false
    property var activeWindowRects: []
    property var prevWindowMap: ({})

    signal windowPhysicsEvent(real sx, real sy, real sw, real vx, real vy, int count, string ignoreAddr)

    function handleWindowSnapshot(snap) {
        try {
            const fs = Boolean(snap.fs);
            const rects = Array.isArray(snap.rects) ? snap.rects : [];
            const now = Date.now();
            const sw = win.width;
            const sh = win.height;

            const nextMap = {};
            for (let i = 0; i < rects.length; i++) {
                const r = rects[i];
                nextMap[r.addr] = {
                    addr: r.addr,
                    cls: r.cls,
                    x: r.x,
                    y: r.y,
                    w: r.w,
                    h: r.h,
                    timeMs: now
                };
            }

            if (!fs) {
                // 1. Closed windows -> drop snow & items immediately
                for (const addr in prevWindowMap) {
                    if (!nextMap[addr]) {
                        const prev = prevWindowMap[addr];
                        const avg = StateStore.shedWindowSnow(addr, 1.0);
                        if (avg > 0.03 && prev.w > 80) {
                            const cnt = Math.min(24, Math.max(6, Math.round(avg * 28)));
                            windowPhysicsEvent(prev.x + 10, prev.y, prev.w - 20, 0, 40, cnt, addr);
                        }
                        StateStore.detachWindowItems(addr, prev, 0, 40, sw, sh, true);
                    }
                }

                // 2. Fast-moved / thrown windows -> launch snow chunks onto neighboring windows
                for (let i = 0; i < rects.length; i++) {
                    const wr = rects[i];
                    const prev = prevWindowMap[wr.addr];
                    if (prev && prev.timeMs) {
                        const dt = Math.max(0.005, (now - prev.timeMs) / 1000.0);
                        const vx = (wr.x - prev.x) / dt;
                        const vy = (wr.y - prev.y) / dt;
                        const spd = Math.sqrt(vx * vx + vy * vy);

                        if (spd > 350) {
                            const fraction = Math.min(0.85, (spd - 300) / 1500.0);
                            const avgSnow = StateStore.shedWindowSnow(wr.addr, fraction);
                            if (avgSnow > 0.04) {
                                const chunkCount = Math.min(28, Math.max(4, Math.round(avgSnow * fraction * 38)));
                                windowPhysicsEvent(wr.x + 10, wr.y, wr.w - 20, vx, vy, chunkCount, wr.addr);
                            }
                        }

                        if (spd > 450) {
                            StateStore.detachWindowItems(wr.addr, prev, vx, vy, sw, sh, false);
                        }
                    }
                }
            }

            prevWindowMap = nextMap;
            activeWindowRects = rects;
            hasFullscreen = fs;
        } catch (e) {
            console.error("Window snapshot error:", e);
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        function onWindowSnapshotReceived(jsonStr) {
            try {
                win.handleWindowSnapshot(JSON.parse(jsonStr));
            } catch (e) {}
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        // 1. 144Hz Falling Weather Layer (Snow, Autumn Leaves, Rain, Cherry Blossom)
        SnowfallLayer {
            id: snowfallLayer
            anchors.fill: parent
            screenW: win.width
            screenH: win.height
            active: !win.hasFullscreen
            snowMode: StateStore.snowMode
            intensity: StateStore.snowIntensity
            windowRects: win.activeWindowRects

            onFlakeLanded: (fx, fy, addr) => {
                if (addr && addr.length > 0 && win.activeWindowRects) {
                    for (let i = 0; i < win.activeWindowRects.length; i++) {
                        const wr = win.activeWindowRects[i];
                        if (wr.addr === addr) {
                            StateStore.depositWindowSnow(addr, fx, wr);
                            break;
                        }
                    }
                } else {
                    StateStore.depositGroundSnow(fx, win.width);
                }
            }

            onChunkLanded: (cx, cy, addr) => {
                if (addr && addr.length > 0 && win.activeWindowRects) {
                    for (let i = 0; i < win.activeWindowRects.length; i++) {
                        const wr = win.activeWindowRects[i];
                        if (wr.addr === addr) {
                            StateStore.depositChunkSnow(addr, cx, wr, win.width);
                            break;
                        }
                    }
                } else {
                    StateStore.depositChunkSnow("", cx, null, win.width);
                }
            }
        }

        // 2. Catmull-Rom Cubic Bézier Snow Dunes (Ground & Windows)
        SnowDriftLayer {
            anchors.fill: parent
            groundBuckets: StateStore.groundSnow
            windowRects: win.activeWindowRects
            windowBucketsMap: StateStore.windowSnow
            snowMode: StateStore.snowMode
        }

        // 3. Bottom Snow Strip (Right-Click + Hold + Drag to roll snowball)
        Item {
            id: bottomSnowStrip
            x: 64
            y: win.height - 34
            width: Math.max(100, win.width - 74)
            height: 34

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                property bool rolling: false
                property int rollBallIdx: -1
                property real rollRadius: 14.0
                property real lastX: 0
                property real lastConsumeX: 0

                onPressed: mouse => {
                    if (mouse.button !== Qt.RightButton) return;
                    const sx = Math.max(72, Math.min(win.width - 16, bottomSnowStrip.x + mouse.x));
                    rolling = true;
                    rollRadius = 14.0;
                    lastX = sx;
                    lastConsumeX = sx;
                    rollBallIdx = StateStore.addSnowball(sx, win.height - 6, rollRadius, "", 0, true, "");
                    StateStore.consumeGroundSnow(sx, win.width, 0.08);
                }

                onPositionChanged: mouse => {
                    if (!rolling || rollBallIdx < 0) return;
                    const sx = Math.max(72, Math.min(win.width - 16, bottomSnowStrip.x + mouse.x));
                    const dx = sx - lastX;
                    lastX = sx;
                    rollRadius = Math.min(40, rollRadius + Math.abs(dx) * 0.055);
                    const deltaAngle = dx / Math.max(8, rollRadius);
                    StateStore.rollSnowball(rollBallIdx, sx, win.height - 6, rollRadius, deltaAngle, "", 0, "");
                    if (Math.abs(sx - lastConsumeX) >= 18) {
                        lastConsumeX = sx;
                        StateStore.consumeGroundSnow(sx, win.width, 0.08);
                    }
                }

                onReleased: mouse => {
                    if (mouse.button !== Qt.RightButton) return;
                    if (rollBallIdx >= 0) StateStore.finishRollSnowball(rollBallIdx);
                    rolling = false;
                    rollBallIdx = -1;
                }

                onCanceled: {
                    if (rollBallIdx >= 0) StateStore.finishRollSnowball(rollBallIdx);
                    rolling = false;
                    rollBallIdx = -1;
                }
            }
        }

        // 4. Window Top Snow Strips (Up to 6 active windows)
        component WindowSnowStrip: Item {
            property var wr: null
            visible: wr !== null && wr.w > 80 && wr.y > 24
            x: wr ? (wr.x + 8) : 0
            y: wr ? (wr.y - 12) : 0
            width: wr ? Math.max(40, wr.w - 16) : 0
            height: 26

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                property bool rolling: false
                property int rollBallIdx: -1
                property real rollRadius: 13.0
                property real lastX: 0
                property real lastConsumeX: 0

                onPressed: mouse => {
                    if (mouse.button !== Qt.RightButton || !wr) return;
                    const sx = parent.x + mouse.x;
                    const sy = wr.y;
                    rolling = true;
                    rollRadius = 13.0;
                    lastX = sx;
                    lastConsumeX = sx;
                    rollBallIdx = StateStore.addSnowball(sx, sy, rollRadius, wr.cls || "", mouse.x, true, wr.addr || "");
                    StateStore.consumeWindowSnow(wr.addr, sx, wr, 0.09);
                }

                onPositionChanged: mouse => {
                    if (!rolling || rollBallIdx < 0 || !wr) return;
                    const sx = parent.x + mouse.x;
                    const dx = sx - lastX;
                    lastX = sx;
                    rollRadius = Math.min(32, rollRadius + Math.abs(dx) * 0.055);
                    const deltaAngle = dx / Math.max(8, rollRadius);
                    StateStore.rollSnowball(rollBallIdx, sx, wr.y, rollRadius, deltaAngle, wr.cls || "", mouse.x, wr.addr || "");
                    if (Math.abs(sx - lastConsumeX) >= 16) {
                        lastConsumeX = sx;
                        StateStore.consumeWindowSnow(wr.addr, sx, wr, 0.09);
                    }
                }

                onReleased: mouse => {
                    if (mouse.button !== Qt.RightButton) return;
                    if (rollBallIdx >= 0) StateStore.finishRollSnowball(rollBallIdx);
                    rolling = false;
                    rollBallIdx = -1;
                }

                onCanceled: {
                    if (rollBallIdx >= 0) StateStore.finishRollSnowball(rollBallIdx);
                    rolling = false;
                    rollBallIdx = -1;
                }
            }
        }

        WindowSnowStrip { id: ws0; wr: win.activeWindowRects.length > 0 ? win.activeWindowRects[0] : null }
        WindowSnowStrip { id: ws1; wr: win.activeWindowRects.length > 1 ? win.activeWindowRects[1] : null }
        WindowSnowStrip { id: ws2; wr: win.activeWindowRects.length > 2 ? win.activeWindowRects[2] : null }
        WindowSnowStrip { id: ws3; wr: win.activeWindowRects.length > 3 ? win.activeWindowRects[3] : null }
        WindowSnowStrip { id: ws4; wr: win.activeWindowRects.length > 4 ? win.activeWindowRects[4] : null }
        WindowSnowStrip { id: ws5; wr: win.activeWindowRects.length > 5 ? win.activeWindowRects[5] : null }

        // 5. Snowballs (144Hz Drag, Roll, Stacking into Snowman, Throwing)
        Repeater {
            model: StateStore.snowballs
            delegate: SnowballItem {
                required property var modelData
                required property int index
                ballData: modelData
                ballIndex: index
                windowRects: win.activeWindowRects
                screenWidth: win.width
                screenHeight: win.height
            }
        }

        // 6. Snowmen (Custom 3-Tier Canvas, Accessories, Hats, Scarves)
        Repeater {
            model: StateStore.snowmen
            delegate: SnowmanItem {
                required property var modelData
                required property int index
                manData: modelData
                manIndex: index
                windowRects: win.activeWindowRects
                screenWidth: win.width
                screenHeight: win.height
            }
        }

        // 7. Trees (Layered Pine Canvas, Lights, Ornaments, Star Topper)
        Repeater {
            model: StateStore.trees
            delegate: TreeItem {
                required property var modelData
                required property int index
                treeData: modelData
                treeIndex: index
                windowRects: win.activeWindowRects
                screenWidth: win.width
                screenHeight: win.height
            }
        }

        // 8. Hanging Garland & Stars
        Repeater {
            model: StateStore.decors
            delegate: DecorItem {
                required property var modelData
                required property int index
                decorData: modelData
                decorIndex: index
            }
        }

        // 9. Manual-Controlled Yellow Bulldozer / Snowplow
        SnowplowItem {
            anchors.fill: parent
            screenWidth: win.width
            screenHeight: win.height
        }

        // 10. Santa Sleigh Flyby
        SantaItem {
            anchors.fill: parent
            screenWidth: win.width
        }

        // 11. Top Control Dock
        WinterDock {
            screenWidth: win.width
            screenHeight: win.height
        }

        // 12. Dress-up Accessory Drawers
        SnowmanCard {
            id: snowmanDrawer
            visible: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx >= 0
            x: Math.max(12, Math.min(win.width - width - 12, (StateStore.selectedSnowmanIdx >= 0 && StateStore.selectedSnowmanIdx < StateStore.snowmen.length) ? (StateStore.snowmen[StateStore.selectedSnowmanIdx].x - 60) : 100))
            y: Math.max(70, Math.min(win.height - height - 16, (StateStore.selectedSnowmanIdx >= 0 && StateStore.selectedSnowmanIdx < StateStore.snowmen.length) ? (StateStore.snowmen[StateStore.selectedSnowmanIdx].y - height - 14) : 100))
        }

        TreeCard {
            id: treeDrawer
            visible: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx >= 0
            x: Math.max(12, Math.min(win.width - width - 12, (StateStore.selectedTreeIdx >= 0 && StateStore.selectedTreeIdx < StateStore.trees.length) ? (StateStore.trees[StateStore.selectedTreeIdx].x - 60) : 100))
            y: Math.max(70, Math.min(win.height - height - 16, (StateStore.selectedTreeIdx >= 0 && StateStore.selectedTreeIdx < StateStore.trees.length) ? (StateStore.trees[StateStore.selectedTreeIdx].y - height - 14) : 100))
        }

        DecorCard {
            id: decorDrawer
            visible: StateStore.activeCard === "decor" && StateStore.selectedDecorIdx >= 0
            x: Math.max(12, Math.min(win.width - width - 12, (StateStore.selectedDecorIdx >= 0 && StateStore.selectedDecorIdx < StateStore.decors.length) ? StateStore.decors[StateStore.selectedDecorIdx].x : 100))
            y: Math.max(70, Math.min(win.height - height - 16, (StateStore.selectedDecorIdx >= 0 && StateStore.selectedDecorIdx < StateStore.decors.length) ? (StateStore.decors[StateStore.selectedDecorIdx].y + 60) : 100))
        }
    }

    onWindowPhysicsEvent: (sx, sy, sw, vx, vy, count, ignoreAddr) => {
        snowfallLayer.spawnSnowChunks(sx, sy, sw, vx, vy, count, ignoreAddr);
    }
}
