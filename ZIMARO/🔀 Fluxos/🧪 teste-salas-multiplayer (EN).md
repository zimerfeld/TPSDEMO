---
tipo: fluxo
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🧪 Test protocol — Multiplayer rooms (P1)

> A **self-sufficient and reusable** script to validate the multi-level server (rooms) in the field.
> It covers 3 network levels, from easiest to most real. Do them in order: if **Test A (loopback)**
> fails, there's no point going to the PCs — it's a code/logic bug, not a network one.
> Context: [[🚪 salas (EN)|Rooms]] · [[🌐 multiplayer (EN)|Multiplayer]] · [[🛰️ hospedagem-online (EN)|Online Hosting]].
>
> **Code-review status (2026-07-01):** the rooms flow (`RoomManager` + `host_session` +
> `client_session` + the levels' `_ready` + lazy template + visibility filters) was **reviewed and
> is consistent — no known bugs**. All that's left is the **run-time validation** below.

---

## Build facts (from the code, for the test)

- **Default port:** `44000` and **default address:** `zimaro.playit.game` (the `Port` SpinBox / `Address` LineEdit of `playonline`; editable and persisted via history). For the local tests in this document, switch to `127.0.0.1` and whichever port you prefer.
- **Server:** button **"Manage Rooms"** → `ENetMultiplayerPeer.create_server(port)` → opens `host_session`.
- **Client:** button **"Join Rooms"** → `create_client(address, port)` → opens `client_session`.
- **Default room (headless server only):** `level_1` (`DEFAULT_ROOM_LEVEL`). In the GUI the host picks the level.
- **Protocol:** ENet over **UDP** → tunnels/networks must forward **UDP** (see Test C).

---

## Test A — Local loopback (2 instances on the SAME PC) · `127.0.0.1`

> ✅ **VALIDATED IN THE FIELD (2026-07-02).** Local `playonline`, host creates a room, client joins and spawns in the room
> (scenery appears, not gray), host shows "(1 connection)", client↔host replication. **The netcode is
> proven.** Only Tests B/C remain (real network transport between 2 PCs). UI adjustments made in the same
> session: non-destructive error window ([[🚪 salas (EN)|Rooms]] "NON-DESTRUCTIVE error window") and a race
> guard on the client's "Play" (don't spawn in a stopped room during `chooseplayer`).
>
> It validates ALL the room logic without depending on a real network. It's the test that I (Claude) can drive
> locally; and the one you run in 1 minute. **If A passes, the netcode is correct** — B/C only exercise
> network transport.

**Setup:** open **two** game windows (the `.exe` in `build/windows/ZIMARO.exe` or two runs
from the editor). Window 1 = HOST, Window 2 = CLIENT.

1. **[HOST]** Menu → **Play Online** → (chooseplayer → levels → playonline) → in PlayOnline, Port `4383`
   → **"Manage Rooms"**. Lands on the `host_session` (empty grid).
2. **[HOST]** Pick **Level 1** in the dropdown → **"Start Room"**. **"Room #1 — level_1 (0 connections)"** appears.
3. **[CLIENT]** Menu → **Play Online** → in PlayOnline, IP `127.0.0.1`, Port `4383` → **"Join Rooms"**.
   Lands on the `client_session` and **lists "Room #1 — level_1"** with a **Play** button.
4. **[CLIENT]** **Play** → picks a character → spawns **inside the room** (renders in the main window).
   - ✅ **Check:** the scenery appears (NOT a gray/black screen), player with a camera, aim works.
   - ✅ **[HOST]** the room's row turns into **"(1 connection)"**.
5. **[HOST]** In room #1, button **Observe** → sees the scenery in the SubViewport; **the client's player appears
     moving** (server→host replication of the client's position). The host's WASD flies the free camera. **ESC** exits.
6. **[HOST]** In room #1, button **Play** → picks a character → spawns in the SAME room.
   - ✅ **[CLIENT]** the HOST's player appears in the client's scene (server→client replication); both see
     and move. Shooting from one should damage the other (replicated combat).
7. **[HOST]** **ESC** while playing → dialog "Disconnect and return to management?" → **Yes** → back to the
   grid with the mouse visible; the host's player disappears from the client's scene.
8. **[HOST]** button **Restart** on the room → ✅ **[CLIENT]** receives **"The level was restarted by the host"**,
   returns to the browser, and the **recreated room (new #id)** reappears in the list to re-enter.
9. **[HOST]** button **Stop** on the room (with the client inside) → ✅ **[CLIENT]** receives **"The level was stopped
   by the host"** and returns to the browser; the room disappears from the host's grid.
10. **[HOST]** **Start** two rooms (Level 1 and Level 2) at once → client joins one; ✅ **isolation:**
    what happens in one room does **not** appear in the other (enemies/players filtered per room).
11. **[CLIENT]** **ESC** in the browser (out of a room) → returns to PlayOnline (closes the peer).
    **[HOST]** **Back** → tears down the server, returns to PlayOnline.

**If any step fails:** note the step + the console (run from the editor to see `push_error`/RPC).
Suspects by symptom: *gray screen on the client* → template/scene-cache (see [[🚪 salas (EN)|Rooms]] "rooms are
born clean"); *player with no camera* → visibility filter (`public_visibility`, see [[🚪 salas (EN)|Rooms]]); *nothing replicates* →
deterministic path `/root/RoomManager/Room<id>/Level`.

---

## Test B — LAN (2 PCs on the SAME network/Wi-Fi)

Same as Test A, but the two machines are physical.

1. On the HOST-PC, find the **local IP**: `ipconfig` → "IPv4 Address" (e.g.: `192.168.0.42`).
2. HOST-PC: hosts (steps 1-2 of Test A).
3. CLIENT-PC: in PlayOnline, IP = **the host's local IP**, Port `4383` → **Join Rooms** → continue from step 3.
4. If it doesn't connect: the **Windows Firewall** on the HOST-PC may be blocking UDP `4383` — open the port
   (or allow the `ZIMARO.exe` the first time Windows asks). Confirm both are on the same subnet.

---

## Test C — Internet (2 PCs on different networks) · playit.gg (UDP)

The game is **UDP** → it needs a UDP tunnel or port forwarding. **ngrok does NOT work (TCP).** Recommended: **playit.gg**.

1. HOST-PC: install the **playit.gg** agent, create a **UDP** tunnel pointing at the local port `4383`.
   playit gives a public address in the format `<sub>.playit.gg` + **one port** (e.g.: `147.185.221.x:xxxxx`).
2. HOST-PC: host normally on port `4383` (**Manage Rooms**).
3. CLIENT-PC: in PlayOnline, IP = **the playit address**, Port = **the playit port** → **Join Rooms**.
   > ⚠️ The client's port is the **public tunnel port**, which may be **different** from `4383`.
4. Follow Test A's verification matrix (steps 4-10).
5. Alternatives: **Tailscale/ZeroTier** (VPN mesh — the client uses the host's `100.x` IP, port `4383`) or
   **port forwarding** on the router (forward UDP `4383` → the host's local IP). See [[🛰️ hospedagem-online (EN)|Online Hosting]].

---

## Capability matrix (what each step proves)

| Capability | Step(s) | Proof |
|---|---|---|
| Server comes up + creates a room | A2 | `create_server` + `start_room` |
| Client connects + lists rooms | A3 | `create_client` + `request_room_list`/`receive_room_list` |
| Client joins and spawns in the room | A4 | `client_join_room`/`join_room` + spawn + local mirror |
| Client→host replication | A5 | per-room visibility + `MultiplayerSynchronizer` |
| **Host plays in the room** | A6 | `host_spawn_in_room` (peer 1) + the player's camera in the SubViewport |
| Host→client replication + combat | A6 | peer 1 spawn replicated + `hit()` RPC |
| Host ESC (leaving play) | A7 | `host_leave_room` |
| Restart room | A8 | `restart_room` + `notify_room_restarted` |
| Stop room | A9 | `stop_room` + `notify_room_closed` |
| Isolation between rooms | A10 | visibility filter by `room_id` |
| Real network (LAN/Internet) | B/C | UDP transport outside loopback |
