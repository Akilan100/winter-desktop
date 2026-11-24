import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property bool hasFullscreen: false
    property var activeWindowRects: []
    property int activeWsId: -1
    property var prevWindowMap: ({})

    signal windowPhysicsEvent(real sx, real sy, real sw, real vx, real vy, int count, string ignoreAddr)

    function handleHyprSnapshot(line) {
        try {
            const snap = JSON.parse(line);
            const wsId = snap.ws !== undefined ? snap.ws : 1;
            const fs = Boolean(snap.fs);
            const rects = Array.isArray(snap.rects) ? snap.rects : [];
            const now = Date.now();

            const scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
            const sw = scr ? scr.width : 1920;
            const sh = scr ? scr.height : 1080;

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

            // Only run window-to-window snow physics within the same workspace
            if (root.activeWsId === wsId && !fs) {
                // 1. Closed / disappeared windows -> drop snow & items immediately (never float in mid-air!)
                for (const addr in root.prevWindowMap) {
                    if (!nextMap[addr]) {
                        const prev = root.prevWindowMap[addr];
                        const avg = StateStore.shedWindowSnow(addr, 1.0);
                        if (avg > 0.03 && prev.w > 80) {
                            const cnt = Math.min(24, Math.max(6, Math.round(avg * 28)));
                            root.windowPhysicsEvent(prev.x + 10, prev.y, prev.w - 20, 0, 40, cnt, addr);
                        }
                        StateStore.detachWindowItems(addr, prev, 0, 40, sw, sh, true);
                    }
                }

                // 2. Fast-moved / thrown / shaken windows -> launch snow chunks & snowballs onto neighboring windows!
                for (let i = 0; i < rects.length; i++) {
                    const wr = rects[i];
                    const prev = root.prevWindowMap[wr.addr];
                    if (!prev) continue;
                    const dx = wr.x - prev.x;
                    const dy = wr.y - prev.y;
                    if (Math.abs(dx) < 2 && Math.abs(dy) < 2) continue;

                    const dt = Math.max(0.006, Math.min(0.15, (now - prev.timeMs) / 1000.0));
                    const vx = dx / dt;
                    const vy = dy / dt;
                    const speed = Math.hypot(vx, vy);

                    if (speed > 420 || vy > 260 || Math.abs(vx) > 380) {
                        const frac = Math.min(0.65, speed / 1800.0);
                        const avg = StateStore.shedWindowSnow(wr.addr, frac);
                        if (avg > 0.03 && wr.w > 80) {
                            const cnt = Math.min(18, Math.max(4, Math.round(avg * 22)));
                            root.windowPhysicsEvent(wr.x + 10, wr.y, wr.w - 20, vx, vy, cnt, wr.addr);
                        }
                        if (speed > 620 || vy > 380) {
                            StateStore.detachWindowItems(wr.addr, prev, vx, vy, sw, sh, false);
                        }
                    }
                }
            }

            root.prevWindowMap = nextMap;
            root.activeWsId = wsId;
            root.hasFullscreen = fs;
            root.activeWindowRects = rects;
        } catch (e) {
        }
    }

    Process {
        id: hyprWatchProc
        running: true
        command: ["/home/beast/hermes_workspace/winter-desktop/bin/hypr-watch.py"]
        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim();
                if (trimmed.length > 0) {
                    root.handleHyprSnapshot(trimmed);
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property ShellScreen modelData

            // Layer 1: 144Hz Snowfall, Snow Drifts, Snowballs, Snowmen, Trees, Decor, Bulldozer & Santa
            PanelWindow {
                id: decorWin
                screen: screenScope.modelData
                WlrLayershell.namespace: "winter-desktop-decor"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: StateStore.behindWindows ? WlrLayer.Bottom : WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                visible: !root.hasFullscreen

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                Region { id: emptyDecorMask }

                component ItemMask: Region {
                    required property Item targetItem
                    property real extraTop: 0
                    property real extraBottom: 0
                    x: targetItem.visible ? targetItem.x : 0
                    y: targetItem.visible ? Math.max(0, targetItem.y - extraTop) : 0
                    width: targetItem.visible ? targetItem.width : 0
                    height: targetItem.visible ? (targetItem.height + extraTop + extraBottom) : 0
                }

                // Reusable Right-Click + Hold + Drag snow-rolling strip for window top ledges (keyed by wr.addr)
                component WindowSnowStrip: Item {
                    id: wStrip
                    required property var wr
                    readonly property bool active: wr !== null && wr.w > 80 && wr.y >= 24
                    visible: active && StateStore.snowMode === 0
                    x: wr ? (wr.x + 8) : 0
                    y: wr ? (wr.y - 22) : 0
                    width: wr ? Math.max(0, wr.w - 16) : 0
                    height: 26

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        property bool rolling: false
                        property int rollBallIdx: -1
                        property real rollRadius: 12.0
                        property real dragAccum: 0
                        property real lastX: 0
                        property real lastConsumeX: 0

                        onPressed: mouse => {
                            if (mouse.button !== Qt.RightButton || !wStrip.wr) return;
                            const pt = mapToItem(decorWin, mouse.x, mouse.y);
                            const sx = Math.max(wStrip.wr.x + 16, Math.min(wStrip.wr.x + wStrip.wr.w - 16, pt.x));
                            rolling = true;
                            rollRadius = 12.0;
                            dragAccum = 0;
                            lastX = sx;
                            lastConsumeX = sx;
                            const bw = Math.max(36, rollRadius * 2 + 16);
                            const offX = sx - wStrip.wr.x - bw / 2;
                            rollBallIdx = StateStore.addSnowball(sx, wStrip.wr.y, rollRadius, wStrip.wr.cls, offX, true, wStrip.wr.addr);
                            StateStore.consumeWindowSnow(wStrip.wr.addr, sx, wStrip.wr, 0.08);
                        }

                        onPositionChanged: mouse => {
                            if (!rolling || rollBallIdx < 0 || !wStrip.wr) return;
                            const pt = mapToItem(decorWin, mouse.x, mouse.y);
                            const sx = Math.max(wStrip.wr.x + 16, Math.min(wStrip.wr.x + wStrip.wr.w - 16, pt.x));
                            const dx = sx - lastX;
                            lastX = sx;
                            dragAccum += Math.abs(dx);

                            rollRadius = Math.min(40, rollRadius + Math.abs(dx) * 0.055);
                            const bw = Math.max(36, rollRadius * 2 + 16);
                            const offX = sx - wStrip.wr.x - bw / 2;
                            const deltaAngle = dx / Math.max(8, rollRadius);
                            StateStore.rollSnowball(rollBallIdx, sx, wStrip.wr.y, rollRadius, deltaAngle, wStrip.wr.cls, offX, wStrip.wr.addr);

                            if (Math.abs(sx - lastConsumeX) >= 18) {
                                lastConsumeX = sx;
                                StateStore.consumeWindowSnow(wStrip.wr.addr, sx, wStrip.wr, 0.08);
                            }
                        }

                        onReleased: mouse => {
                            if (mouse.button !== Qt.RightButton) return;
                            if (rollBallIdx >= 0) {
                                StateStore.finishRollSnowball(rollBallIdx);
                            }
                            rolling = false;
                            rollBallIdx = -1;
                        }

                        onCanceled: {
                            if (rollBallIdx >= 0) {
                                StateStore.finishRollSnowball(rollBallIdx);
                            }
                            rolling = false;
                            rollBallIdx = -1;
                        }
                    }
                }

                mask: root.hasFullscreen ? emptyDecorMask : decorMask

                Region {
                    id: decorMask
                    // Bottom snow strip for Right-Click + Hold + Drag snowball rolling
                    Region { item: bottomSnowStrip }
                    // Window top snow strips (only active where real snow has landed!)
                    ItemMask { targetItem: ws0 }
                    ItemMask { targetItem: ws1 }
                    ItemMask { targetItem: ws2 }
                    ItemMask { targetItem: ws3 }
                    ItemMask { targetItem: ws4 }
                    ItemMask { targetItem: ws5 }
                    // Bulldozer (including manual control bar above it)
                    ItemMask { targetItem: snowplow; extraTop: snowplow.showControls ? 42 : 0 }
                    // Trees (3)
                    ItemMask { targetItem: tr0 }
                    ItemMask { targetItem: tr1 }
                    ItemMask { targetItem: tr2 }
                    // Snowmen (5)
                    ItemMask { targetItem: sm0 }
                    ItemMask { targetItem: sm1 }
                    ItemMask { targetItem: sm2 }
                    ItemMask { targetItem: sm3 }
                    ItemMask { targetItem: sm4 }
                    // Snowballs (10)
                    ItemMask { targetItem: sb0; extraTop: sb0.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb1; extraTop: sb1.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb2; extraTop: sb2.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb3; extraTop: sb3.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb4; extraTop: sb4.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb5; extraTop: sb5.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb6; extraTop: sb6.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb7; extraTop: sb7.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb8; extraTop: sb8.menuOpen ? 36 : 0 }
                    ItemMask { targetItem: sb9; extraTop: sb9.menuOpen ? 36 : 0 }
                    // Decorations (16)
                    ItemMask { targetItem: dc0; extraBottom: (dc0.hovered || dc0.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc1; extraBottom: (dc1.hovered || dc1.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc2; extraBottom: (dc2.hovered || dc2.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc3; extraBottom: (dc3.hovered || dc3.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc4; extraBottom: (dc4.hovered || dc4.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc5; extraBottom: (dc5.hovered || dc5.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc6; extraBottom: (dc6.hovered || dc6.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc7; extraBottom: (dc7.hovered || dc7.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc8; extraBottom: (dc8.hovered || dc8.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc9; extraBottom: (dc9.hovered || dc9.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc10; extraBottom: (dc10.hovered || dc10.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc11; extraBottom: (dc11.hovered || dc11.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc12; extraBottom: (dc12.hovered || dc12.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc13; extraBottom: (dc13.hovered || dc13.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc14; extraBottom: (dc14.hovered || dc14.selected) ? 34 : 0 }
                    ItemMask { targetItem: dc15; extraBottom: (dc15.hovered || dc15.selected) ? 34 : 0 }
                }

                // True 144Hz VSync falling snowflakes + flying window-to-window snow chunks
                SnowfallLayer {
                    id: snowfallLayer
                    anchors.fill: parent
                    screenW: decorWin.width
                    screenH: decorWin.height
                    active: !root.hasFullscreen
                    snowMode: StateStore.snowMode
                    intensity: StateStore.snowIntensity
                    windowRects: root.activeWindowRects

                    Connections {
                        target: root
                        function onWindowPhysicsEvent(sx, sy, sw, vx, vy, count, ignoreAddr) {
                            snowfallLayer.spawnSnowChunks(sx, sy, sw, vx, vy, count, ignoreAddr);
                        }
                    }

                    onFlakeLanded: (fx, fy, addr) => {
                        if (addr && addr.length > 0 && root.activeWindowRects) {
                            for (let i = 0; i < root.activeWindowRects.length; i++) {
                                const wr = root.activeWindowRects[i];
                                if (wr.addr === addr) {
                                    StateStore.depositWindowSnow(addr, fx, wr);
                                    break;
                                }
                            }
                        } else {
                            StateStore.depositGroundSnow(fx, decorWin.width);
                        }
                    }

                    onChunkLanded: (cx, cy, addr) => {
                        if (addr && addr.length > 0 && root.activeWindowRects) {
                            for (let i = 0; i < root.activeWindowRects.length; i++) {
                                const wr = root.activeWindowRects[i];
                                if (wr.addr === addr) {
                                    StateStore.depositChunkSnow(addr, cx, wr, decorWin.width);
                                    break;
                                }
                            }
                        } else {
                            StateStore.depositChunkSnow("", cx, null, decorWin.width);
                        }
                    }
                }

                // Organic snow drifts built strictly from landed snowflakes & jumped snow chunks
                SnowDriftLayer {
                    anchors.fill: parent
                    groundBuckets: StateStore.groundSnow
                    windowRects: root.activeWindowRects
                    windowBucketsMap: StateStore.windowSnow
                    snowMode: StateStore.snowMode
                }

                // Bottom snow strip: Right-Click + Hold + Drag continuously to roll a growing snowball!
                Item {
                    id: bottomSnowStrip
                    x: 64
                    y: decorWin.height - 34
                    width: Math.max(100, decorWin.width - 74)
                    height: 34

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        property bool rolling: false
                        property int rollBallIdx: -1
                        property real rollRadius: 14.0
                        property real dragAccum: 0
                        property real lastX: 0
                        property real lastConsumeX: 0

                        onPressed: mouse => {
                            if (mouse.button !== Qt.RightButton) return;
                            const sx = Math.max(72, Math.min(decorWin.width - 16, bottomSnowStrip.x + mouse.x));
                            rolling = true;
                            rollRadius = 14.0;
                            dragAccum = 0;
                            lastX = sx;
                            lastConsumeX = sx;
                            rollBallIdx = StateStore.addSnowball(sx, decorWin.height - 6, rollRadius, "", 0, true, "");
                            StateStore.consumeGroundSnow(sx, decorWin.width, 0.08);
                        }

                        onPositionChanged: mouse => {
                            if (!rolling || rollBallIdx < 0) return;
                            const sx = Math.max(72, Math.min(decorWin.width - 16, bottomSnowStrip.x + mouse.x));
                            const dx = sx - lastX;
                            lastX = sx;
                            dragAccum += Math.abs(dx);

                            rollRadius = Math.min(40, rollRadius + Math.abs(dx) * 0.055);
                            const deltaAngle = dx / Math.max(8, rollRadius);
                            StateStore.rollSnowball(rollBallIdx, sx, decorWin.height - 6, rollRadius, deltaAngle, "", 0, "");

                            if (Math.abs(sx - lastConsumeX) >= 18) {
                                lastConsumeX = sx;
                                StateStore.consumeGroundSnow(sx, decorWin.width, 0.08);
                            }
                        }

                        onReleased: mouse => {
                            if (mouse.button !== Qt.RightButton) return;
                            if (rollBallIdx >= 0) {
                                StateStore.finishRollSnowball(rollBallIdx);
                            }
                            rolling = false;
                            rollBallIdx = -1;
                        }

                        onCanceled: {
                            if (rollBallIdx >= 0) {
                                StateStore.finishRollSnowball(rollBallIdx);
                            }
                            rolling = false;
                            rollBallIdx = -1;
                        }
                    }
                }

                // Window top snow strips (up to 6 visible windows)
                WindowSnowStrip { id: ws0; wr: root.activeWindowRects.length > 0 ? root.activeWindowRects[0] : null }
                WindowSnowStrip { id: ws1; wr: root.activeWindowRects.length > 1 ? root.activeWindowRects[1] : null }
                WindowSnowStrip { id: ws2; wr: root.activeWindowRects.length > 2 ? root.activeWindowRects[2] : null }
                WindowSnowStrip { id: ws3; wr: root.activeWindowRects.length > 3 ? root.activeWindowRects[3] : null }
                WindowSnowStrip { id: ws4; wr: root.activeWindowRects.length > 4 ? root.activeWindowRects[4] : null }
                WindowSnowStrip { id: ws5; wr: root.activeWindowRects.length > 5 ? root.activeWindowRects[5] : null }

                // Snow splatters from thrown snowballs (fade out smoothly)
                Repeater {
                    model: StateStore.splats
                    delegate: Item {
                        id: splatItem
                        required property var modelData
                        x: modelData.x - width / 2
                        y: modelData.y - height / 2
                        width: modelData.size || 44
                        height: width
                        opacity: 0.92

                        SequentialAnimation on opacity {
                            running: true
                            PauseAnimation { duration: 2200 }
                            NumberAnimation { to: 0.0; duration: 1800; easing.type: Easing.OutQuad }
                            ScriptAction { script: StateStore.removeSplatById(splatItem.modelData.id) }
                        }

                        Canvas {
                            anchors.fill: parent
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                const cx = width / 2;
                                const cy = height / 2;
                                ctx.fillStyle = "rgba(255, 255, 255, 0.88)";
                                for (let i = 0; i < 7; i++) {
                                    const ang = i * (Math.PI * 2 / 7);
                                    const dist = (i === 0) ? 0 : width * 0.22;
                                    const r = (i === 0) ? width * 0.26 : width * (0.10 + (i % 3) * 0.04);
                                    ctx.beginPath();
                                    ctx.arc(cx + Math.cos(ang) * dist, cy + Math.sin(ang) * dist, r, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }
                        }
                    }
                }

                // Sparkle / powder burst when stacking snowballs into a snowman!
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

                // 3 Tree slots
                TreeItem { id: tr0; visible: StateStore.trees.length > 0; itemIndex: 0; itemData: StateStore.trees.length > 0 ? StateStore.trees[0] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 0; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }
                TreeItem { id: tr1; visible: StateStore.trees.length > 1; itemIndex: 1; itemData: StateStore.trees.length > 1 ? StateStore.trees[1] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 1; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }
                TreeItem { id: tr2; visible: StateStore.trees.length > 2; itemIndex: 2; itemData: StateStore.trees.length > 2 ? StateStore.trees[2] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === 2; onClicked: idx => { if (StateStore.activeCard === "tree" && StateStore.selectedTreeIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedTreeIdx = idx; StateStore.activeCard = "tree"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateTree(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }) }

                // 5 Snowman slots
                SnowmanItem { id: sm0; visible: StateStore.snowmen.length > 0; itemIndex: 0; itemData: StateStore.snowmen.length > 0 ? StateStore.snowmen[0] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 0; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
                SnowmanItem { id: sm1; visible: StateStore.snowmen.length > 1; itemIndex: 1; itemData: StateStore.snowmen.length > 1 ? StateStore.snowmen[1] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 1; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
                SnowmanItem { id: sm2; visible: StateStore.snowmen.length > 2; itemIndex: 2; itemData: StateStore.snowmen.length > 2 ? StateStore.snowmen[2] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 2; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
                SnowmanItem { id: sm3; visible: StateStore.snowmen.length > 3; itemIndex: 3; itemData: StateStore.snowmen.length > 3 ? StateStore.snowmen[3] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 3; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }
                SnowmanItem { id: sm4; visible: StateStore.snowmen.length > 4; itemIndex: 4; itemData: StateStore.snowmen.length > 4 ? StateStore.snowmen[4] : null; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === 4; onClicked: idx => { if (StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx === idx) StateStore.activeCard = ""; else { StateStore.selectedSnowmanIdx = idx; StateStore.activeCard = "snowman"; } }; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowman(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onScaled: (idx, s) => StateStore.updateSnowman(idx, { scale: s }) }

                // 10 Interactive Snowball slots (roll, throw, splat, jump windows, stack 3 -> Snowman!)
                SnowballItem { id: sb0; visible: StateStore.snowballs.length > 0; itemIndex: 0; itemData: StateStore.snowballs.length > 0 ? StateStore.snowballs[0] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 0; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb1; visible: StateStore.snowballs.length > 1; itemIndex: 1; itemData: StateStore.snowballs.length > 1 ? StateStore.snowballs[1] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 1; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb2; visible: StateStore.snowballs.length > 2; itemIndex: 2; itemData: StateStore.snowballs.length > 2 ? StateStore.snowballs[2] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 2; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb3; visible: StateStore.snowballs.length > 3; itemIndex: 3; itemData: StateStore.snowballs.length > 3 ? StateStore.snowballs[3] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 3; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb4; visible: StateStore.snowballs.length > 4; itemIndex: 4; itemData: StateStore.snowballs.length > 4 ? StateStore.snowballs[4] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 4; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb5; visible: StateStore.snowballs.length > 5; itemIndex: 5; itemData: StateStore.snowballs.length > 5 ? StateStore.snowballs[5] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 5; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb6; visible: StateStore.snowballs.length > 6; itemIndex: 6; itemData: StateStore.snowballs.length > 6 ? StateStore.snowballs[6] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 6; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb7; visible: StateStore.snowballs.length > 7; itemIndex: 7; itemData: StateStore.snowballs.length > 7 ? StateStore.snowballs[7] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 7; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb8; visible: StateStore.snowballs.length > 8; itemIndex: 8; itemData: StateStore.snowballs.length > 8 ? StateStore.snowballs[8] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 8; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }
                SnowballItem { id: sb9; visible: StateStore.snowballs.length > 9; itemIndex: 9; itemData: StateStore.snowballs.length > 9 ? StateStore.snowballs[9] : null; allSnowballs: StateStore.snowballs; windowRects: root.activeWindowRects; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedSnowballIdx === 9; onClicked: idx => StateStore.selectedSnowballIdx = idx; onMoved: (idx, nx, ny, cls, offX, addr) => StateStore.updateSnowball(idx, { x: nx, y: ny, attachedClass: cls, offsetX: offX, attachedAddr: addr }); onStackRequested: (s, d) => StateStore.stackSnowball(s, d); onSplatRequested: (idx, sx, sy, sz) => { StateStore.removeSnowball(idx); StateStore.addSplat(sx, sy, sz); } }

                // 16 Decoration slots
                DecorItem { id: dc0; visible: StateStore.decors.length > 0; itemIndex: 0; itemData: StateStore.decors.length > 0 ? StateStore.decors[0] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 0; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc1; visible: StateStore.decors.length > 1; itemIndex: 1; itemData: StateStore.decors.length > 1 ? StateStore.decors[1] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 1; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc2; visible: StateStore.decors.length > 2; itemIndex: 2; itemData: StateStore.decors.length > 2 ? StateStore.decors[2] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 2; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc3; visible: StateStore.decors.length > 3; itemIndex: 3; itemData: StateStore.decors.length > 3 ? StateStore.decors[3] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 3; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc4; visible: StateStore.decors.length > 4; itemIndex: 4; itemData: StateStore.decors.length > 4 ? StateStore.decors[4] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 4; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc5; visible: StateStore.decors.length > 5; itemIndex: 5; itemData: StateStore.decors.length > 5 ? StateStore.decors[5] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 5; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc6; visible: StateStore.decors.length > 6; itemIndex: 6; itemData: StateStore.decors.length > 6 ? StateStore.decors[6] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 6; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc7; visible: StateStore.decors.length > 7; itemIndex: 7; itemData: StateStore.decors.length > 7 ? StateStore.decors[7] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 7; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc8; visible: StateStore.decors.length > 8; itemIndex: 8; itemData: StateStore.decors.length > 8 ? StateStore.decors[8] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 8; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc9; visible: StateStore.decors.length > 9; itemIndex: 9; itemData: StateStore.decors.length > 9 ? StateStore.decors[9] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 9; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc10; visible: StateStore.decors.length > 10; itemIndex: 10; itemData: StateStore.decors.length > 10 ? StateStore.decors[10] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 10; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc11; visible: StateStore.decors.length > 11; itemIndex: 11; itemData: StateStore.decors.length > 11 ? StateStore.decors[11] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 11; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc12; visible: StateStore.decors.length > 12; itemIndex: 12; itemData: StateStore.decors.length > 12 ? StateStore.decors[12] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 12; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc13; visible: StateStore.decors.length > 13; itemIndex: 13; itemData: StateStore.decors.length > 13 ? StateStore.decors[13] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 13; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc14; visible: StateStore.decors.length > 14; itemIndex: 14; itemData: StateStore.decors.length > 14 ? StateStore.decors[14] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 14; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }
                DecorItem { id: dc15; visible: StateStore.decors.length > 15; itemIndex: 15; itemData: StateStore.decors.length > 15 ? StateStore.decors[15] : null; screenW: decorWin.width; screenH: decorWin.height; selected: StateStore.selectedDecorIdx === 15; onClicked: idx => StateStore.selectedDecorIdx = (StateStore.selectedDecorIdx === idx ? -1 : idx); onMoved: (idx, nx, ny) => StateStore.updateDecor(idx, { x: nx, y: ny }); onUpdated: (idx, p) => StateStore.updateDecor(idx, p); onRemoved: idx => StateStore.removeDecor(idx) }

                // Yellow Bulldozer / Snowplow (100% user-controlled, 144Hz)
                SnowplowItem {
                    id: snowplow
                    screenW: decorWin.width
                    screenH: decorWin.height
                    active: StateStore.plowActive
                    snowmen: StateStore.snowmen
                    onSweepStep: (px, pw) => StateStore.sweepAtX(px, pw, decorWin.height, decorWin.width)
                    onClosed: StateStore.plowActive = false
                }

                // Santa & Reindeer Sleigh (144Hz)
                SantaItem {
                    id: santaSleigh
                    screenW: decorWin.width
                    screenH: decorWin.height
                    active: StateStore.santaActive
                    onFinished: StateStore.santaActive = false
                }
            }

            // Layer 2: Floating Winter Dock & Customization Cards (always Top, click-through outside UI)
            PanelWindow {
                id: uiWin
                screen: screenScope.modelData
                WlrLayershell.namespace: "winter-desktop-ui"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                visible: !root.hasFullscreen

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                Region { id: emptyUiMask }

                mask: root.hasFullscreen ? emptyUiMask : uiMask

                Region {
                    id: uiMask
                    Region {
                        x: winterDock.x
                        y: winterDock.y
                        width: winterDock.width
                        height: winterDock.height
                    }
                    Region {
                        x: snowmanCard.visible ? snowmanCard.x : 0
                        y: snowmanCard.visible ? snowmanCard.y : 0
                        width: snowmanCard.visible ? snowmanCard.width : 0
                        height: snowmanCard.visible ? snowmanCard.height : 0
                    }
                    Region {
                        x: treeCard.visible ? treeCard.x : 0
                        y: treeCard.visible ? treeCard.y : 0
                        width: treeCard.visible ? treeCard.width : 0
                        height: treeCard.visible ? treeCard.height : 0
                    }
                    Region {
                        x: decorCard.visible ? decorCard.x : 0
                        y: decorCard.visible ? decorCard.y : 0
                        width: decorCard.visible ? decorCard.width : 0
                        height: decorCard.visible ? decorCard.height : 0
                    }
                }

                WinterDock {
                    id: winterDock
                    screenW: uiWin.width
                    screenH: uiWin.height
                    x: Math.round((uiWin.width + 60 - width) / 2)
                    y: 16
                }

                SnowmanCard {
                    id: snowmanCard
                    visible: StateStore.activeCard === "snowman" && StateStore.selectedSnowmanIdx >= 0 && StateStore.selectedSnowmanIdx < StateStore.snowmen.length
                    snowmanIndex: StateStore.selectedSnowmanIdx
                    snowmanData: visible ? StateStore.snowmen[StateStore.selectedSnowmanIdx] : null
                    x: Math.round((uiWin.width + 60 - width) / 2)
                    y: 78
                    onCloseRequested: StateStore.activeCard = ""
                }

                TreeCard {
                    id: treeCard
                    visible: StateStore.activeCard === "tree" && StateStore.selectedTreeIdx >= 0 && StateStore.selectedTreeIdx < StateStore.trees.length
                    treeIndex: StateStore.selectedTreeIdx
                    treeData: visible ? StateStore.trees[StateStore.selectedTreeIdx] : null
                    x: Math.round((uiWin.width + 60 - width) / 2)
                    y: 78
                    onCloseRequested: StateStore.activeCard = ""
                }

                DecorCard {
                    id: decorCard
                    visible: StateStore.activeCard === "decor"
                    screenW: uiWin.width
                    screenH: uiWin.height
                    x: Math.round((uiWin.width + 60 - width) / 2)
                    y: 78
                    onCloseRequested: StateStore.activeCard = ""
                }
            }
        }
    }
}
