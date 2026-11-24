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

        // 5. Sparkle / powder burst when stacking snowballs into a snowman!
        Item {
            id: burstFx
            visible: false
            width: 140; height: 140
            property real prog: 0
            property string kind: "stack"

            Connections {
                target: StateStore
                function onSnowballBurst(bx, by, kind) {
                    burstFx.x = bx - burstFx.width / 2;
                    burstFx.y = by - burstFx.height / 2;
                    burstFx.kind = kind;
                    burstFx.visible = true;
                    burstAnim.restart();
                }
            }

            NumberAnimation {
                id: burstAnim
                target: burstFx
                property: "prog"
                from: 0.0; to: 1.0; duration: 550
                easing.type: Easing.OutCubic
                onFinished: burstFx.visible = false
            }

            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property real ang: index * (Math.PI * 2 / 10)
                    readonly property real dist: 12 + burstFx.prog * (burstFx.kind === "snowman" ? 62 : 38)
                    x: burstFx.width / 2 + Math.cos(ang) * dist - width / 2
                    y: burstFx.height / 2 + Math.sin(ang) * dist - height / 2
                    width: burstFx.kind === "snowman" ? 10 : 7
                    height: width
                    radius: width / 2
                    color: burstFx.kind === "snowman" ? (index % 2 === 0 ? "#fde047" : "#ffffff") : "#e0f2fe"
                    opacity: 1.0 - burstFx.prog
                }
            }
        }

        // 6. Tree slots
        TreeItem { id: tr0; visible: StateStore.trees.length > 0; itemIndex: 0; itemData: StateStore.trees.length > 0 ? StateStore.trees[0] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 0; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }
        TreeItem { id: tr1; visible: StateStore.trees.length > 1; itemIndex: 1; itemData: StateStore.trees.length > 1 ? StateStore.trees[1] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 1; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }
        TreeItem { id: tr2; visible: StateStore.trees.length > 2; itemIndex: 2; itemData: StateStore.trees.length > 2 ? StateStore.trees[2] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 2; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }

        // 7. Snowman slots
        SnowmanItem { id: sm0; visible: StateStore.snowmen.length > 0; itemIndex: 0; itemData: StateStore.snowmen.length > 0 ? StateStore.snowmen[0] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 0; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
        SnowmanItem { id: sm1; visible: StateStore.snowmen.length > 1; itemIndex: 1; itemData: StateStore.snowmen.length > 1 ? StateStore.snowmen[1] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 1; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
        SnowmanItem { id: sm2; visible: StateStore.snowmen.length > 2; itemIndex: 2; itemData: StateStore.snowmen.length > 2 ? StateStore.snowmen[2] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 2; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
        SnowmanItem { id: sm3; visible: StateStore.snowmen.length > 3; itemIndex: 3; itemData: StateStore.snowmen.length > 3 ? StateStore.snowmen[3] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 3; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
        SnowmanItem { id: sm4; visible: StateStore.snowmen.length > 4; itemIndex: 4; itemData: StateStore.snowmen.length > 4 ? StateStore.snowmen[4] : null; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 4; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }

        // 8. Snowball slots (roll, stack, throw, splat)
        SnowballItem { id: sb0; visible: StateStore.snowballs.length > 0; itemIndex: 0; itemData: StateStore.snowballs.length > 0 ? StateStore.snowballs[0] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 0; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
        SnowballItem { id: sb1; visible: StateStore.snowballs.length > 1; itemIndex: 1; itemData: StateStore.snowballs.length > 1 ? StateStore.snowballs[1] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 1; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
        SnowballItem { id: sb2; visible: StateStore.snowballs.length > 2; itemIndex: 2; itemData: StateStore.snowballs.length > 2 ? StateStore.snowballs[2] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 2; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
        SnowballItem { id: sb3; visible: StateStore.snowballs.length > 3; itemIndex: 3; itemData: StateStore.snowballs.length > 3 ? StateStore.snowballs[3] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 3; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
        SnowballItem { id: sb4; visible: StateStore.snowballs.length > 4; itemIndex: 4; itemData: StateStore.snowballs.length > 4 ? StateStore.snowballs[4] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 4; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
        SnowballItem { id: sb5; visible: StateStore.snowballs.length > 5; itemIndex: 5; itemData: StateStore.snowballs.length > 5 ? StateStore.snowballs[5] : null; allSnowballs: StateStore.snowballs; windowRects: win.activeWindowRects; screenW: win.width; screenH: win.height; selected: StateStore.selectedSnowballIdx === 5; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }

        // 9. Decoration slots
        DecorItem { id: dc0; visible: StateStore.decors.length > 0; itemIndex: 0; itemData: StateStore.decors.length > 0 ? StateStore.decors[0] : null; screenW: win.width; screenH: win.height; selected: StateStore.selectedDecorIdx === 0; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
        DecorItem { id: dc1; visible: StateStore.decors.length > 1; itemIndex: 1; itemData: StateStore.decors.length > 1 ? StateStore.decors[1] : null; screenW: win.width; screenH: win.height; selected: StateStore.selectedDecorIdx === 1; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
        DecorItem { id: dc2; visible: StateStore.decors.length > 2; itemIndex: 2; itemData: StateStore.decors.length > 2 ? StateStore.decors[2] : null; screenW: win.width; screenH: win.height; selected: StateStore.selectedDecorIdx === 2; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
        DecorItem { id: dc3; visible: StateStore.decors.length > 3; itemIndex: 3; itemData: StateStore.decors.length > 3 ? StateStore.decors[3] : null; screenW: win.width; screenH: win.height; selected: StateStore.selectedDecorIdx === 3; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }

        // 10. Manual-Controlled Yellow Bulldozer / Snowplow
        SnowplowItem {
            id: snowplow
            screenW: win.width
            screenH: win.height
            active: StateStore.plowActive
            snowmen: StateStore.snowmen
            onSweepStep: (px, pw) => StateStore.sweepAtX(px, pw, win.height, win.width)
            onClosed: StateStore.plowActive = false
        }

        // 11. Santa Sleigh Flyby
        SantaItem {
            id: santaSleigh
            screenW: win.width
            screenH: win.height
            active: StateStore.santaActive
            onFinished: StateStore.santaActive = false
        }

        // 12. Top Control Dock
        WinterDock {
            screenW: win.width
            screenH: win.height
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
