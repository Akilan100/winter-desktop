pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool loaded: false
    property bool behindWindows: false
    property bool dockCollapsed: false
    property int snowMode: 0 // 0=Snow, 1=Autumn Leaves, 2=Rain, 3=Cherry Blossom
    property int snowIntensity: 75

    property var snowmen: []
    property var trees: []
    property var decors: []
    property var snowballs: [] // transient interactive snowballs (up to 10)
    property var splats: []    // transient snow splatters (up to 8)

    // Real snow accumulation buckets (0.0 = bare, 1.0 = deep drift)
    property var groundSnow: [0.28,0.31,0.34,0.36,0.35,0.32,0.29,0.27,0.28,0.31,0.35,0.37,0.36,0.33,0.29,0.27,0.28,0.32,0.35,0.37,0.35,0.31,0.28,0.27,0.29,0.33,0.36,0.37,0.34,0.30,0.27,0.28,0.31,0.35,0.37,0.35,0.31,0.28,0.27,0.29,0.33,0.36,0.37,0.34,0.30,0.28,0.27,0.28]
    property var windowSnow: ({})
    property int snowTick: 0

    property int selectedSnowmanIdx: -1
    property int selectedTreeIdx: -1
    property int selectedDecorIdx: -1
    property int selectedSnowballIdx: -1
    property string activeCard: "" // "", "snowman", "tree", "decor"

    property bool plowActive: false
    property bool santaActive: false

    signal stateChanged()
    signal snowballBurst(real bx, real by, string kind) // "stack", "snowman", "splat"

    function defaultState() {
        return {
            behindWindows: false,
            dockCollapsed: false,
            snowmen: [
                {
                    id: 1,
                    x: 1520,
                    y: 760,
                    scale: 1.0,
                    hat: "tophat",
                    face: "happy",
                    body: "mittens",
                    clothes: "scarf",
                    attachedClass: "",
                    offsetX: 0
                }
            ],
            trees: [
                {
                    id: 1,
                    x: 1660,
                    y: 640,
                    sizeLevel: 2,
                    topper: "star",
                    ornaments: ["baubles", "lights", "candy_canes", "garland"],
                    attachedClass: "",
                    offsetX: 0
                }
            ],
            decors: [
                {
                    id: 1,
                    kind: "star",
                    x: 1690,
                    y: 110,
                    scale: 1.0,
                    rotation: 0
                }
            ]
        };
    }

    function applyData(data) {
        if (!data) return;
        behindWindows = Boolean(data.behindWindows);
        dockCollapsed = Boolean(data.dockCollapsed);
        if (data.snowIntensity !== undefined && data.snowIntensity >= 25) {
            snowIntensity = data.snowIntensity;
        }
        if (data.snowMode !== undefined) {
            snowMode = data.snowMode;
        }
        snowmen = Array.isArray(data.snowmen) ? data.snowmen : [];
        trees = Array.isArray(data.trees) ? data.trees : [];
        decors = Array.isArray(data.decors) ? data.decors : [];
        loaded = true;
        stateChanged();
    }

    function save() {
        if (!loaded) return;
        saveNow();
    }

    function saveNow() {
        if (!loaded) return;
        const payload = {
            behindWindows: behindWindows,
            dockCollapsed: dockCollapsed,
            snowIntensity: snowIntensity,
            snowMode: snowMode,
            snowmen: snowmen,
            trees: trees,
            decors: decors
        };
        if (typeof backend !== "undefined" && backend && backend.saveState) {
            backend.saveState(JSON.stringify(payload));
        }
    }

    // --- Snowballs & Stacking into Snowman ---
    function addSnowball(x, y, radius, attachedClass, offsetX, isRolling, attachedAddr) {
        const next = snowballs.slice();
        if (next.length >= 10) next.shift();
        next.push({
            id: Date.now() + Math.floor(Math.random() * 1000),
            x: x,
            y: y,
            radius: radius || 18,
            tier: 1,
            rollAngle: 0,
            rolling: Boolean(isRolling),
            attachedClass: attachedClass || "",
            attachedAddr: attachedAddr || "",
            offsetX: offsetX || 0,
            launchVx: 0,
            launchVy: 0,
            launchSeq: 0
        });
        snowballs = next;
        return snowballs.length - 1;
    }

    function rollSnowball(idx, nx, ny, newRadius, deltaAngle, attachedClass, offsetX, attachedAddr) {
        if (idx < 0 || idx >= snowballs.length) return;
        const next = snowballs.slice();
        const cur = next[idx];
        next[idx] = Object.assign({}, cur, {
            x: nx,
            y: ny,
            radius: Math.max(6, Math.min(40, newRadius)),
            rollAngle: (cur.rollAngle || 0) + deltaAngle,
            rolling: true,
            attachedClass: attachedClass !== undefined ? attachedClass : cur.attachedClass,
            attachedAddr: attachedAddr !== undefined ? attachedAddr : cur.attachedAddr,
            offsetX: offsetX !== undefined ? offsetX : cur.offsetX
        });
        snowballs = next;
    }

    function finishRollSnowball(idx) {
        if (idx < 0 || idx >= snowballs.length) return;
        updateSnowball(idx, { rolling: false });
    }

    function updateSnowball(idx, patch) {
        if (idx < 0 || idx >= snowballs.length) return;
        const next = snowballs.slice();
        next[idx] = Object.assign({}, next[idx], patch);
        snowballs = next;
    }

    function removeSnowball(idx) {
        if (idx < 0 || idx >= snowballs.length) return;
        const next = snowballs.slice();
        next.splice(idx, 1);
        snowballs = next;
        if (selectedSnowballIdx === idx) selectedSnowballIdx = -1;
        else if (selectedSnowballIdx > idx) selectedSnowballIdx -= 1;
    }

    function growSnowball(idx, delta) {
        if (idx < 0 || idx >= snowballs.length) return;
        const b = snowballs[idx];
        const nr = Math.max(12, Math.min(36, (b.radius || 18) + delta));
        updateSnowball(idx, { radius: nr });
    }

    function stackSnowball(srcIdx, dstIdx) {
        if (srcIdx < 0 || srcIdx >= snowballs.length || dstIdx < 0 || dstIdx >= snowballs.length || srcIdx === dstIdx) return;
        const dst = snowballs[dstIdx];
        const src = snowballs[srcIdx];
        const dstTier = dst.tier || 1;
        const srcTier = src.tier || 1;
        const totalBalls = dstTier + srcTier;

        if (totalBalls >= 3) {
            const smX = dst.x - 70;
            const smY = dst.y - 161;
            const attached = dst.attachedClass || "";
            const attachedAddr = dst.attachedAddr || "";
            const offX = (dst.attachedAddr || dst.attachedClass) ? ((dst.offsetX || 0) + (dst.radius || 20) + 8 - 70) : 0;

            const next = snowballs.slice();
            const hi = Math.max(srcIdx, dstIdx);
            const lo = Math.min(srcIdx, dstIdx);
            next.splice(hi, 1);
            next.splice(lo, 1);
            snowballs = next;
            selectedSnowballIdx = -1;

            addSnowmanAt(smX, smY, attached, offX, attachedAddr);
            snowballBurst(dst.x, dst.y - 40, "snowman");
        } else {
            const next = snowballs.slice();
            next[dstIdx] = Object.assign({}, dst, {
                tier: 2,
                radius: Math.max(dst.radius || 22, 24)
            });
            next.splice(srcIdx, 1);
            snowballs = next;
            selectedSnowballIdx = -1;
            snowballBurst(dst.x, dst.y - 20, "stack");
        }
    }

    function promoteSnowballStack(idx) {
        if (idx < 0 || idx >= snowballs.length) return;
        const b = snowballs[idx];
        if ((b.tier || 1) === 1) {
            updateSnowball(idx, { tier: 2, radius: Math.max(b.radius || 22, 24) });
            snowballBurst(b.x, b.y - 20, "stack");
        } else {
            const smX = b.x - 70;
            const smY = b.y - 160;
            const attached = b.attachedClass || "";
            const offX = b.offsetX ? (b.offsetX - 40) : 0;
            removeSnowball(idx);
            addSnowmanAt(smX, smY, attached, offX);
            snowballBurst(b.x, b.y - 40, "snowman");
        }
    }

    function addSplat(x, y, size) {
        const next = splats.slice();
        if (next.length >= 8) next.shift();
        next.push({
            id: Date.now() + Math.floor(Math.random() * 1000),
            x: x,
            y: y,
            size: size || 44
        });
        splats = next;
        snowballBurst(x, y, "splat");
    }

    function removeSplatById(id) {
        const next = splats.filter(s => s.id !== id);
        if (next.length !== splats.length) splats = next;
    }

    // --- Accumulation, Carving & Window Physics ---
    function depositGroundSnow(x, screenW) {
        const idx = groundBucketAt(x, screenW);
        const gNext = groundSnow.slice();
        const weights = [0.12, 0.38, 0.76, 1.0, 0.76, 0.38, 0.12];
        const maxCap = (snowMode === 2) ? 0.32 : 1.0;
        const baseAmt = (snowMode === 2) ? 0.012 : 0.022;
        for (let o = -3; o <= 3; o++) {
            const k = idx + o;
            if (k >= 0 && k < gNext.length) {
                gNext[k] = Math.min(maxCap, gNext[k] + baseAmt * weights[o + 3]);
            }
        }
        groundSnow = gNext;
    }

    function depositWindowSnow(addr, x, wr) {
        if (!addr || !wr) return;
        const wNext = Object.assign({}, windowSnow);
        const arr = wNext[addr] ? wNext[addr].slice() : [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        const idx = windowBucketAt(x, wr);
        const weights = [0.25, 0.70, 1.0, 0.70, 0.25];
        const maxCap = (snowMode === 2) ? 0.26 : 0.82;
        const baseAmt = (snowMode === 2) ? 0.009 : 0.016;
        for (let o = -2; o <= 2; o++) {
            const k = idx + o;
            if (k >= 0 && k < arr.length) {
                arr[k] = Math.min(maxCap, arr[k] + baseAmt * weights[o + 2]);
            }
        }
        wNext[addr] = arr;
        windowSnow = wNext;
    }

    function depositChunkSnow(addr, x, wr, screenW) {
        if (addr && wr) {
            const wNext = Object.assign({}, windowSnow);
            const arr = wNext[addr] ? wNext[addr].slice() : [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
            const idx = windowBucketAt(x, wr);
            const weights = [0.35, 0.75, 1.0, 0.75, 0.35];
            const amt = 0.045;
            for (let o = -2; o <= 2; o++) {
                const k = idx + o;
                if (k >= 0 && k < arr.length) {
                    arr[k] = Math.min(0.88, arr[k] + amt * weights[o + 2]);
                }
            }
            wNext[addr] = arr;
            windowSnow = wNext;
        } else {
            const idx = groundBucketAt(x, screenW);
            const gNext = groundSnow.slice();
            const weights = [0.20, 0.60, 1.0, 0.60, 0.20];
            const amt = 0.045;
            for (let o = -2; o <= 2; o++) {
                const k = idx + o;
                if (k >= 0 && k < gNext.length) {
                    gNext[k] = Math.min(1.0, gNext[k] + amt * weights[o + 2]);
                }
            }
            groundSnow = gNext;
        }
    }

    function shedWindowSnow(addr, fraction) {
        if (!addr || !windowSnow[addr]) return 0;
        const arr = windowSnow[addr];
        let sum = 0;
        for (let i = 0; i < arr.length; i++) sum += arr[i];
        const avg = sum / arr.length;
        if (avg < 0.03) {
            if (fraction >= 0.99) {
                const wNext = Object.assign({}, windowSnow);
                delete wNext[addr];
                windowSnow = wNext;
            }
            return 0;
        }
        const wNext = Object.assign({}, windowSnow);
        if (fraction >= 0.99) {
            delete wNext[addr];
        } else {
            const nextArr = arr.slice();
            const keep = Math.max(0, 1.0 - fraction);
            for (let i = 0; i < nextArr.length; i++) nextArr[i] *= keep;
            wNext[addr] = nextArr;
        }
        windowSnow = wNext;
        return avg;
    }

    function detachWindowItems(addr, prevWr, vx, vy, screenW, screenH, isClosed) {
        let ballsChanged = false;
        const nextBalls = snowballs.slice();
        for (let i = 0; i < nextBalls.length; i++) {
            const b = nextBalls[i];
            if (b.attachedAddr === addr || (!b.attachedAddr && prevWr && b.attachedClass === prevWr.cls)) {
                const bw = Math.max(36, (b.radius || 20) * 2 + 16);
                const curX = prevWr ? (prevWr.x + (b.offsetX || 0) + bw / 2) : b.x;
                const curY = prevWr ? prevWr.y : b.y;
                nextBalls[i] = Object.assign({}, b, {
                    x: curX,
                    y: curY,
                    attachedAddr: "",
                    attachedClass: "",
                    offsetX: 0,
                    rolling: false,
                    launchVx: vx * 0.78,
                    launchVy: isClosed ? 40 : Math.min(-90, vy * 0.65 - 130),
                    launchSeq: (b.launchSeq || 0) + 1
                });
                ballsChanged = true;
            }
        }
        if (ballsChanged) snowballs = nextBalls;

        if (isClosed) {
            let smChanged = false;
            const nextSm = snowmen.slice();
            for (let i = 0; i < nextSm.length; i++) {
                const sm = nextSm[i];
                if (sm.attachedAddr === addr || (!sm.attachedAddr && prevWr && sm.attachedClass === prevWr.cls)) {
                    const sc = sm.scale || 1.0;
                    const curX = prevWr ? Math.max(64, Math.min(screenW - 140 * sc - 12, prevWr.x + (sm.offsetX || 0))) : sm.x;
                    nextSm[i] = Object.assign({}, sm, {
                        x: curX,
                        y: Math.max(12, screenH - 175 * sc - 8),
                        attachedAddr: "",
                        attachedClass: "",
                        offsetX: 0
                    });
                    smChanged = true;
                }
            }
            if (smChanged) { snowmen = nextSm; save(); }

            let trChanged = false;
            const nextTr = trees.slice();
            for (let i = 0; i < nextTr.length; i++) {
                const tr = nextTr[i];
                if (tr.attachedAddr === addr || (!tr.attachedAddr && prevWr && tr.attachedClass === prevWr.cls)) {
                    const scales = [0.55, 0.78, 1.0, 1.28, 1.58];
                    const sc = scales[Math.max(0, Math.min(4, tr.sizeLevel !== undefined ? tr.sizeLevel : 2))];
                    const curX = prevWr ? Math.max(64, Math.min(screenW - 190 * sc - 12, prevWr.x + (tr.offsetX || 0))) : tr.x;
                    nextTr[i] = Object.assign({}, tr, {
                        x: curX,
                        y: Math.max(12, screenH - 250 * sc - 8),
                        attachedAddr: "",
                        attachedClass: "",
                        offsetX: 0
                    });
                    trChanged = true;
                }
            }
            if (trChanged) { trees = nextTr; save(); }
        }
    }

    function windowHasAnySnow(addr) {
        if (!addr || !windowSnow[addr]) return false;
        const arr = windowSnow[addr];
        for (let i = 0; i < arr.length; i++) {
            if (arr[i] >= 0.12) return true;
        }
        return false;
    }

    function groundBucketAt(x, screenW) {
        const span = Math.max(100, screenW - 74);
        const t = Math.max(0, Math.min(1, (x - 64) / span));
        return Math.round(t * (groundSnow.length - 1));
    }

    function hasGroundSnowAt(x, screenW) {
        const idx = groundBucketAt(x, screenW);
        let sum = 0, cnt = 0;
        for (let k = Math.max(0, idx - 1); k <= Math.min(groundSnow.length - 1, idx + 1); k++) {
            sum += groundSnow[k];
            cnt += 1;
        }
        return cnt > 0 && (sum / cnt) >= 0.12;
    }

    function consumeGroundSnow(x, screenW, amount) {
        const idx = groundBucketAt(x, screenW);
        const gNext = groundSnow.slice();
        for (let k = Math.max(0, idx - 1); k <= Math.min(gNext.length - 1, idx + 1); k++) {
            const w = (k === idx) ? 1.0 : 0.55;
            gNext[k] = Math.max(0.0, gNext[k] - amount * w);
        }
        groundSnow = gNext;
    }

    function windowBucketAt(x, wr) {
        const span = Math.max(20, wr.w - 20);
        const t = Math.max(0, Math.min(1, (x - (wr.x + 10)) / span));
        return Math.round(t * 23);
    }

    function hasWindowSnowAt(addr, x, wr) {
        if (!addr || !windowSnow[addr]) return false;
        const arr = windowSnow[addr];
        const idx = windowBucketAt(x, wr);
        let sum = 0, cnt = 0;
        for (let k = Math.max(0, idx - 1); k <= Math.min(arr.length - 1, idx + 1); k++) {
            sum += arr[k];
            cnt += 1;
        }
        return cnt > 0 && (sum / cnt) >= 0.12;
    }

    function consumeWindowSnow(addr, x, wr, amount) {
        if (!addr || !windowSnow[addr]) return;
        const wNext = Object.assign({}, windowSnow);
        const arr = wNext[addr].slice();
        const idx = windowBucketAt(x, wr);
        for (let k = Math.max(0, idx - 1); k <= Math.min(arr.length - 1, idx + 1); k++) {
            const w = (k === idx) ? 1.0 : 0.55;
            arr[k] = Math.max(0.0, arr[k] - amount * w);
        }
        wNext[addr] = arr;
        windowSnow = wNext;
    }

    function sweepAtX(plowX, plowW, screenH, screenW) {
        const gNext = groundSnow.slice();
        const span = Math.max(100, (screenW || 1920) - 74);
        let clearedAny = false;
        for (let i = 0; i < gNext.length; i++) {
            const bx = 64 + (i / (gNext.length - 1)) * span;
            if (bx >= plowX - 8 && bx <= plowX + plowW + 8 && gNext[i] > 0.01) {
                gNext[i] = 0.0;
                clearedAny = true;
            }
        }
        if (clearedAny) groundSnow = gNext;

        const nextBalls = [];
        for (let i = 0; i < snowballs.length; i++) {
            const b = snowballs[i];
            const nearGround = b.y >= screenH - 110;
            const hitX = b.x + (b.radius || 20) >= plowX && b.x - (b.radius || 20) <= plowX + plowW;
            if (nearGround && hitX) {
                snowballBurst(b.x, b.y, "splat");
            } else {
                nextBalls.push(b);
            }
        }
        if (nextBalls.length !== snowballs.length) snowballs = nextBalls;

        const nextSplats = splats.filter(s => !(s.y >= screenH - 110 && s.x >= plowX - 20 && s.x <= plowX + plowW + 20));
        if (nextSplats.length !== splats.length) splats = nextSplats;
    }

    function triggerSnowplow() {
        plowActive = !plowActive;
    }

    function clearSnowhush() {
        groundSnow = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        windowSnow = ({});
        if (typeof backend !== "undefined" && backend && backend.clearSnow) {
            backend.clearSnow();
        }
    }

    function setSnowhushIntensity(val) {
        snowIntensity = val;
        save();
        if (typeof backend !== "undefined" && backend && backend.setIntensity) {
            backend.setIntensity(val);
        }
    }

    function triggerSanta() {
        santaActive = true;
    }

    // --- Snowmen ---
    function addSnowmanAt(x, y, attachedClass, offsetX, attachedAddr) {
        const next = snowmen.slice();
        if (next.length >= 5) next.shift();
        next.push({
            id: Date.now(),
            x: Math.max(70, x),
            y: Math.max(40, y),
            scale: 1.0,
            hat: "none",
            face: "classic",
            body: "sticks",
            clothes: "scarf",
            attachedClass: attachedClass || "",
            attachedAddr: attachedAddr || "",
            offsetX: offsetX || 0
        });
        snowmen = next;
        selectedSnowmanIdx = snowmen.length - 1;
        activeCard = "snowman";
        stateChanged();
        save();
    }

    function addSnowman(screenW, screenH) {
        if (snowmen.length >= 5) {
            selectedSnowmanIdx = snowmen.length - 1;
            activeCard = "snowman";
            return;
        }
        const idx = snowmen.length;
        addSnowmanAt(
            Math.max(120, Math.min(screenW - 220, screenW - 360 - idx * 150)),
            Math.max(120, screenH - 220),
            "",
            0
        );
    }

    function updateSnowman(idx, patch) {
        if (idx < 0 || idx >= snowmen.length) return;
        const next = snowmen.slice();
        next[idx] = Object.assign({}, next[idx], patch);
        snowmen = next;
        stateChanged();
        save();
    }

    function removeSnowman(idx) {
        if (idx < 0 || idx >= snowmen.length) return;
        const next = snowmen.slice();
        next.splice(idx, 1);
        snowmen = next;
        if (selectedSnowmanIdx === idx) {
            selectedSnowmanIdx = -1;
            if (activeCard === "snowman") activeCard = "";
        } else if (selectedSnowmanIdx > idx) {
            selectedSnowmanIdx -= 1;
        }
        stateChanged();
        save();
    }

    // --- Trees ---
    function addTree(screenW, screenH) {
        if (trees.length >= 3) {
            selectedTreeIdx = trees.length - 1;
            activeCard = "tree";
            return;
        }
        const idx = trees.length;
        const next = trees.slice();
        next.push({
            id: Date.now(),
            x: Math.max(120, Math.min(screenW - 260, 180 + idx * 220)),
            y: Math.max(120, screenH - 360),
            sizeLevel: 2,
            topper: "star",
            ornaments: ["baubles", "lights"],
            attachedClass: "",
            offsetX: 0
        });
        trees = next;
        selectedTreeIdx = trees.length - 1;
        activeCard = "tree";
        stateChanged();
        save();
    }

    function updateTree(idx, patch) {
        if (idx < 0 || idx >= trees.length) return;
        const next = trees.slice();
        next[idx] = Object.assign({}, next[idx], patch);
        trees = next;
        stateChanged();
        save();
    }

    function removeTree(idx) {
        if (idx < 0 || idx >= trees.length) return;
        const next = trees.slice();
        next.splice(idx, 1);
        trees = next;
        if (selectedTreeIdx === idx) {
            selectedTreeIdx = -1;
            if (activeCard === "tree") activeCard = "";
        } else if (selectedTreeIdx > idx) {
            selectedTreeIdx -= 1;
        }
        stateChanged();
        save();
    }

    // --- Decorations ---
    function addDecor(kind, screenW, screenH) {
        if (decors.length >= 16) return;
        const next = decors.slice();
        const offset = (next.length % 5) * 48;
        let dx = Math.round(screenW * 0.5 - 60 + offset);
        let dy = Math.round(screenH * 0.25 + offset);
        if (kind === "lights") {
            dx = Math.round(screenW * 0.25);
            dy = 24;
        } else if (kind === "star") {
            dx = Math.round(screenW * 0.78);
            dy = 90 + (next.length % 3) * 40;
        }
        next.push({
            id: Date.now() + next.length,
            kind: kind,
            x: dx,
            y: dy,
            scale: 1.0,
            rotation: 0
        });
        decors = next;
        selectedDecorIdx = decors.length - 1;
        stateChanged();
        save();
    }

    function updateDecor(idx, patch) {
        if (idx < 0 || idx >= decors.length) return;
        const next = decors.slice();
        next[idx] = Object.assign({}, next[idx], patch);
        decors = next;
        stateChanged();
        save();
    }

    function removeDecor(idx) {
        if (idx < 0 || idx >= decors.length) return;
        const next = decors.slice();
        next.splice(idx, 1);
        decors = next;
        if (selectedDecorIdx === idx) selectedDecorIdx = -1;
        else if (selectedDecorIdx > idx) selectedDecorIdx -= 1;
        stateChanged();
        save();
    }

    function clearDecors() {
        decors = [];
        selectedDecorIdx = -1;
        stateChanged();
        save();
    }

    function setSnowhushMode(modeNum) {
        snowMode = modeNum;
        save();
        if (typeof backend !== "undefined" && backend && backend.setMode) {
            backend.setMode(modeNum);
        }
    }

    function quitAll() {
        saveNow();
        if (typeof backend !== "undefined" && backend && backend.quitApp) {
            backend.quitApp();
        }
    }

    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend && backend.loadState) {
            try {
                const s = backend.loadState();
                if (s && s.length > 5) {
                    applyData(JSON.parse(s));
                } else {
                    applyData(defaultState());
                }
            } catch (e) {
                applyData(defaultState());
            }
        } else {
            applyData(defaultState());
        }
    }
}
