#!/usr/bin/env python3
import glob
import json
import os
import select
import socket
import sys
import time


def find_hypr_dir():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xrd = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if sig:
        p = os.path.join(xrd, "hypr", sig)
        if os.path.exists(os.path.join(p, ".socket.sock")):
            return p
    candidates = sorted(glob.glob(os.path.join(xrd, "hypr", "*")), key=os.path.getmtime, reverse=True)
    for c in candidates:
        if os.path.exists(os.path.join(c, ".socket.sock")):
            return c
    return None


def query_sock(sock_path, cmd):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.2)
    s.connect(sock_path)
    s.sendall(cmd)
    chunks = []
    while True:
        data = s.recv(16384)
        if not data:
            break
        chunks.append(data)
    s.close()
    return b"".join(chunks).decode("utf-8", errors="replace")


def snapshot(sock_path):
    ws = json.loads(query_sock(sock_path, b"j/activeworkspace"))
    clients = json.loads(query_sock(sock_path, b"j/clients"))
    ws_id = ws.get("id", 1)
    fs = bool(ws.get("hasfullscreen", False))
    rects = []
    for c in clients:
        if not c.get("mapped") or c.get("hidden"):
            continue
        cws = c.get("workspace") or {}
        if cws.get("id") == ws_id:
            c_fs = c.get("fullscreen", 0)
            if isinstance(c_fs, int) and c_fs >= 2:
                fs = True
            elif c_fs is True:
                fs = True
            at = c.get("at") or [0, 0]
            sz = c.get("size") or [0, 0]
            rects.append({
                "addr": c.get("address", ""),
                "cls": c.get("class", ""),
                "x": at[0],
                "y": at[1],
                "w": sz[0],
                "h": sz[1],
                "floating": bool(c.get("floating", False)),
            })
    rects.sort(key=lambda r: r["addr"])
    return {"ws": ws_id, "fs": fs, "rects": rects}


def main():
    hdir = find_hypr_dir()
    if not hdir:
        sys.exit(1)
    sock1 = os.path.join(hdir, ".socket.sock")
    sock2 = os.path.join(hdir, ".socket2.sock")

    ev_sock = None
    try:
        ev_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        ev_sock.connect(sock2)
        ev_sock.setblocking(False)
    except Exception:
        ev_sock = None

    last_payload = None
    fast_until = time.monotonic() + 1.5

    while True:
        now = time.monotonic()
        if ev_sock is not None:
            r, _, _ = select.select([ev_sock], [], [], 0.0)
            if r:
                try:
                    chunk = ev_sock.recv(8192)
                    if chunk:
                        fast_until = now + 1.5
                except BlockingIOError:
                    pass
                except Exception:
                    ev_sock = None

        try:
            snap = snapshot(sock1)
            payload = json.dumps(snap, separators=(",", ":"))
            if payload != last_payload:
                last_payload = payload
                fast_until = now + 1.5
                sys.stdout.write(payload + "\n")
                sys.stdout.flush()
        except Exception:
            pass

        # 144Hz (~6.9ms) while windows are moving/active, 50Hz (20ms) when completely idle
        time.sleep(0.0069 if time.monotonic() < fast_until else 0.020)


if __name__ == "__main__":
    main()
