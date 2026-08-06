---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🛰️ Online Hosting (playing with friends over the internet)

> How to expose the host machine so another player can connect over the internet.
> Related: [[🌐 multiplayer (EN)|Multiplayer]]

---

## Technical context

- The game uses **ENetMultiplayerPeer** → `create_server()` / `create_client()` in `scenes2D/playonline/playonline.gd`.
- ENet runs over **UDP**. The default port is **UDP 44000** (`playonline.tscn`, `Port` SpinBox, `value = 44000`) — the same port as the project's playit tunnel. It was `4383` until 2026-08-06.
- The **Address** field accepts a hostname, so you can use domains instead of an IP. A **format hint** below the field (`AddressFormatHint`) says so: "Accepts a domain (e.g. `zimaro.playit.game`) or an IP — the port goes in the Port field."
- **Asynchronous DNS resolution (2026-08-06).** ENet's `create_client` resolves hostnames on its own, but **blocking** — on a slow network the frame stalls until DNS answers and the game looks frozen. Now `_on_join_rooms_pressed` only calls `create_client` with an **already-resolved IP**:
  - Literal IP (`is_valid_ip_address()`) → connects straight away, nothing to resolve.
  - Hostname → `IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)` (resolver queue, runs on a thread) and `_process` polls the status via `_poll_resolve()` without blocking; on completion it calls `_start_client(ip, host)`.
  - **IPv4 preference** (`_pick_address`): playit publishes both A and AAAA and the resolver usually returns the IPv6 first (`zimaro.playit.game` → `2602:fbaf:824:1::1d` and `147.185.221.29`). Connecting over IPv6 would shut out players with no IPv6 route, so we pick the first address **without** a colon; IPv6 is used only when there is no IPv4.
  - **Status label** (`ConnectStatus`, group `loc_manual`): "Resolving address…" → "Connecting…", cleared on abort. A DNS failure shows its own notice (`MSG_RESOLVE_FAILED`) with the typed name; an empty field warns before trying (`MSG_EMPTY_ADDRESS`).
  - **Status and "Loading" never overlap (2026-08-06).** The *Loading* panel (with its progress bar) no longer shows alongside "Connecting…": `_start_client` only sets up the peer and the signals; `loading.show()` (and `_clear_status()`) moved to `_on_client_connected_await_version`, which runs when ENet **closes** the connection. The visible order becomes *Resolving → Connecting →* (connected) *→ Loading*, the latter covering the version handshake until the room browser opens.
  - The queue item is released (`erase_resolve_item`) on completion and in `_exit_tree`, so nothing leaks between visits to the screen.
- The **Port** field accepts **1–65535**. (Before, the SpinBox `max_value` was 49151, which **truncated** dynamic ports like playit's — e.g.: typing 54417 became 49151 and the connection failed. Fixed to 65535.)
- **Port/IP history:** next to Port and Address there is an `OptionButton` ("Select…") with the **last 3 values** used. Persisted in `Settings.config_file` under section **`online`** (keys `ports` / `addresses`), reloaded in `_ready` (`_refresh_history`). Selecting an item fills the field and the dropdown goes back to "Select…".
  - The Address field stores the **raw text** — it works the same for an **IP** (`147.185.221.26`) and a **domain** (`wharf-pos.gl.at.ply.gg`).
  - Recorded: on clicking **Host**/**Connect** (`_remember`), on pressing **Enter** and when the field **loses focus** (`_on_address_focus_exited` / `_on_port_focus_exited` — Port saves via the SpinBox's `get_line_edit().focus_exited`). Updates the dropdown immediately. A domain connects directly — resolved beforehand on the `IP` async queue (see "Asynchronous DNS resolution" above).
  - **Full domains saved (2026-06-25):** every **full domain** (FQDN — has a letter and a dot, e.g.: `wharf-pos.gl.at.ply.gg`) also enters its own PERSISTENT list (section `online`, key `domains`, cap `DOMAIN_MAX = 12`) that **does not roll over** together with the recent IPs. The Address dropdown joins the recent addresses **+ these saved domains**, deduplicated (`_fill_address_history`, `_remember_address`, `_is_full_domain`) — so a domain typed once stays available for selection even after using several IPs.
- **Screen layout** (`playonline.tscn`): each input has a localized **Label on the left** — `Port:` (PT "Porta:") and `IP Address/Domain:` (PT "Endereço IP/Domínio:"), via `Resources/playonline.*.json`. **Below** Port/Address there are two buttons (no radios; directly clickable):
  - **ManageRooms** ("Manage Rooms", `_on_manage_rooms_pressed`) = **Host** role: creates a **persistent** ENet server and opens the `host_session` (room manager). See [[🚪 salas (EN)|Rooms]].
  - **JoinRooms** ("Join Rooms", `_on_join_rooms_pressed`) = **Client** role: connects as a client and, on `connected_to_server`, opens the `client_session` (room browser).
  - The old single-level buttons (**Host and Connect / Host Only / Connect**) and the reconnect probe ("probe") **were removed** — the flow is now rooms-only. The `playonline`'s **"Back"** returns to the menu; the sessions' Back returns to `playonline` (tearing down the peer).
  - **Headless (dedicated server):** `playonline` calls `_on_manage_rooms_pressed` and auto-starts a room with `level_1` (`DEFAULT_ROOM_LEVEL`).

> **Joining a match in progress:** in the rooms flow the client simply picks a **running room**
> in the browser (`client_session`) and joins — the server spawns the player in it. There is no longer
> the scene probe nor the reconnect `ConfirmationDialog` (those belonged to the old single-level "Connect").
> See [[🚪 salas (EN)|Rooms]], [[🌐 multiplayer (EN)|Multiplayer]].

> ⚠️ **ngrok does NOT work** here: ngrok only tunnels **TCP/HTTP**, it doesn't support **UDP**. Without changing the game to WebSocket/TCP, no ngrok configuration will connect to the ENet host.

---

## Free observation camera ("Observe" a room)

In the `host_session`, **Observe** on a room shows the level live (robots, connected players) via a
free camera, **with no collision and no controlled player**.

- **Flow:** the camera is added by `RoomManager.register_room_level` in each server room. On
  clicking **Observe**, the room switches to `UPDATE_ALWAYS` and its texture is shown fullscreen; the mouse is
  **captured** and pushed to the SubViewport (`push_input`) → the camera looks around. **ESC** exits the
  observation. (On the host's **"Play"**, this camera is **turned off** and gives way to the player's camera.)
- **Camera** (`scenes3D/spectator_camera/spectator_camera.{gd,tscn}`): a `Camera3D` that is a **direct
  child of the level** (outside `SpawnedNodes` → **does not replicate**; it exists only in the server instance). It doesn't consume a
  spawn point — all of them are left for the clients.
- **Controls:** **WASD** flies on the plane (relative to the camera yaw); **mouse** looks around (mouse
  captured); **Space+W** goes up and **Space+S** goes down **at the player's jump speed**
  (`VERTICAL_SPEED = 5.0 = Player.JUMP_SPEED`); the speed is smoothed by `lerp` (start/stop without
  a jolt).

---

## Option 1 — playit.gg (ngrok replacement, supports UDP, free)

1. Download and run the agent at https://playit.gg
2. Create a tunnel of type **UDP** pointing at `127.0.0.1:4383`
3. **Proxy Protocol:** ❌ **disabled** (Godot's ENet doesn't understand the PROXY header — it would break the connection)
4. playit generates a public address, e.g.: `wharf-pos.gl.at.ply.gg:54417`
5. Host: open the game → **Manage Rooms** and **Start Room**. Friend: **Address** = domain, **Port** = the port from the panel → **Join Rooms** → **Play** in the room

### Why connect to the playit domain and not to the local IP (`192.168.x.x`)

They are **two ends of the same tunnel**, and only one is reachable over the internet:

```
Friend (internet)           playit.gg (cloud)          Your machine (LAN)
────────────────            ─────────────────          ──────────────────
wharf-pos…:54417  ─UDP►   playit relay server    ─►   playit agent   ─►  192.168.0.33:4383
 (PUBLIC address)           (routable IP on the net)   (on your PC)        (game / ENet)
```

- `192.168.0.33:4383` is a **private LAN IP** — it only exists inside your network; nobody on the internet can reach it. It is the *internal* destination the agent delivers the traffic to.
- `wharf-pos.gl.at.ply.gg:54417` is the **public address** created on playit's relays — that one is reachable from anywhere.
- The agent on your PC keeps the tunnel open: packets to `…:54417` → relay → agent → `192.168.0.33:4383` (game). That's why you should **never share the `192.168…`** (it means nothing outside your network) and the **public port** (54417) is different from the local one (4383).

### Values in the PlayOnline UI (`playonline.gd`)

| Role | Address | Port | How |
|---|---|---|---|
| **Host** | *(ignored — can be left empty)* | `4383` (the same as the tunnel) | **Manage Rooms** |
| **Client** | `wharf-pos.gl.at.ply.gg` (domain only, **without** `:port`) | `54417` (the **public** port from the panel) | **Join Rooms** |

- **Host** (`_on_manage_rooms_pressed`): `create_server(port)` uses **only the port**, never the Address. This port must be the same one the playit tunnel redirects (local address `4383`).
- **Client** (`_on_join_rooms_pressed`): `create_client(address, port)` — domain in one field, port in the other. ENet resolves the hostname, so **domain = IP**. Don't paste `domain:port` in the Address: the `:port` goes in the separate **Port** field.

### Stability of the generated values
- **Domain + port** (`xxxxx.gl.at.ply.gg:PORT`): **fixed while the tunnel exists**. They change if the tunnel is **deleted and recreated** (random port on the free plan).
- **Raw IP** (`147.185.221.26:...`): **shared/anycast, may change** — **don't share it**. Always pass the **domain**.
- Permanent/custom address: only on the **paid** plans.

### Version handshake (host and client on the same build)
Since 2026-08-05, on connect the host and client exchange a **build ID**: `RoomManager` sends its version
on `peer_connected` and the client compares in `receive_host_version`. If the versions **differ**, the
client **refuses** with *"Incompatible versions — Host: X, You: Y"* (PT/EN/ES) instead of failing silently;
if the host is an old build that never answers, a **5 s timeout** shows *"Could not verify the host's
version"*. The ID is stamped at export by `build_windows.ps1` **deterministically** via
`git describe --tags --dirty --always` (`build_id.json` = the exact tag when the commit sits on a tag, e.g.
`202608051426`; else `<tag>-<n>-g<sha>`; `-dirty` suffix if there are uncommitted changes; read by
`RoomManager.game_version`, embedded in the `.exe`). In the **editor** everyone matches (`editor-dev`). Rule
of thumb: **run the same `.exe`** — and since the ID is now deterministic, **building the same commit** also
yields the same ID and matches in the handshake. See [[🌐 multiplayer (EN)]].

### Common errors
- **`RequiresVerifiedAccount`**: the playit account needs a **verified e-mail**. Resolve at https://playit.gg/account by adding an e-mail + confirming, **or** logging in via **Discord/Google** (already verified).
- The **public port** may differ from 4383 — the friend must use the port shown in the **playit panel**.

---

## Option 2 — Tailscale or ZeroTier (virtual LAN / VPN — more reliable)

Creates a local network between the machines, without touching the router or exposing a port on the internet.

1. Host and friend install **Tailscale** (https://tailscale.com) and log into the **same network** (Google/etc. login)
2. Host opens the game → **Manage Rooms** (port 4383) and starts a room
3. Friend: **Join Rooms** using the **host machine's Tailscale IP** (e.g.: `100.x.x.x`) + port **4383**

- **Advantages:** good latency, stable, nothing exposed publicly, **no account verification**.
- **ZeroTier** is equivalent (virtual network with a shared network ID).

---

## Option 3 — Port forwarding on the router (no extra program)

1. Forward **UDP 4383** to the local IP of the host machine
2. Open the port in the **Windows Firewall** (UDP 4383, inbound)
3. Friend connects to the host's **public IP** (https://whatismyip.com) + port 4383

- **Downside:** it exposes the port publicly and depends on the carrier's NAT (**CGNAT** may block it).

---

## Recommendation

- Quick play with friends → **Tailscale** (Option 2).
- ngrok-style "public" address → **playit.gg** (Option 1).
