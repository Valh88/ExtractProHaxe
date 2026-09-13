# AGENTS.md

Haxe/HashLink physics demo built on the local `HeapsPhysics` haxelib (`phys.*`, wraps Oimo). No package.json, no tests, no CI — verification = both targets compile + headless server runs.

## Build & run

hxml files live at repo root; output goes to gitignored `bin/`.

```sh
haxe win.hxml       # client -> bin/client/client.hl
hl bin/client/client.hl   # opens a window

haxe web.hxml       # client -> bin/web/game.js  (HTML5 / WebGL2 target)
                     # serve bin/web/ over http (file:// will not load resources)

haxe server.hxml    # headless server -> bin/server/serv.hl
hl bin/server/serv.hl     # runs ~15s then exits (Config.SERVER_RUN_SECONDS)
```

- `linx.hxml` is broken (stale Linux path) — always use `win.hxml` for the HL client target.
- Both `win.hxml` and `web.hxml` hard-code `-cp /home/vano/.haxe_lib/oimophysics/git/src` — an
  absolute path to a dev-machine checkout; builds fail anywhere else until this is fixed.
  `web.hxml` overrides it on the next line with a local `-cp D:/projects/haxe/OimoPhysics/src`;
  the stale Linux line should be deleted from both hxml files.
- Deps are dev-installed haxelibs: `heapsphysics` (provides `phys.*`), `oimophysics`, `heaps`, `format`.
- Client build emits many `(WDeprecated) @:extern` warnings from oimophysics — harmless, not errors.

## Networking — hx_rnl (RNL) + RPC layer

Multiplayer prototype: **HL-only** (UDP/RNL). The web target has no UDP — all networking
lives under `#if sys` and `web.hxml` is untouched. `-lib hxrnl` is in `win.hxml` and
`server.hxml` (dev haxelib at `D:/projects/pascal/rnl/hx_rnl/`; `haxelib path hxrnl` adds
`-L .../ndll/` for the HL `.hdll`).

### Runtime files (required to RUN a `.hl`)

`hl client.hl`/`serv.hl` fails with `FATAL ERROR : Failed to load library rnl.hdll` unless the
native libs are findable. Copy BOTH from `D:/projects/pascal/rnl/hx_rnl/ndll/win64/`:

- `rnl.hdll` — **must be the `win64/` build**; the `ndll/HL64/rnl.hdll` does NOT load on this
  machine (spike-verified). 
- `RNL.dll`

Place them next to the `.hl` (project convention): `bin/client/` and `bin/server/` (HL also
finds them next to `hl.exe`; next-to-`.hl` is preferred here, matching the `cd bin/client`
run pattern). They are gitignored with `bin/`, so **re-copy after a clean checkout**.

### Build targets & run

```sh
haxe server.hxml            # bin/server/serv.hl (headless, ~15s then exits)
# from repo root (data.cdb path is client/res/db/data.cdb vs cwd), HL_PATH for rnl.hdll:
$env:HL_PATH="bin/server"; hl bin/server/serv.hl

haxe win.hxml               # bin/client/client.hl (GUI, starts in Lobby)
# run from its own folder (res.pak convention), or root; rnl.hdll+RNL.dll in bin/client

# headless client test (no GUI):
haxe netclienttest.hxml     # -main NetClientTest -hl bin/clienttest.hl
$env:HL_PATH="bin/client"; hl bin/clienttest.hl
```

### Architecture — per-room socket, socket lives in a System

- **Server**: a room/lobby owns its RNL socket through a `System` in `roomSystems`. 
  `LobbyRoom` creates `serv/systems/NetRoomSystem` (owns `SocketHost` + shared `LobbyNet`
  facade, polls `socket.update(0)` in `update()`, disposed by `roomSystems.clear()` in
  `Room.close()`). Future game rooms (`MapRoom`) reuse the same system with different RPC
  handlers. Each room = its own UDP socket; the room ticks its own `service()` loop.
- **Client**: a scene owns its socket through a presentation `System` in `BaseScene.systems`.
  `LobbyView` adds `extract/systems/LobbyNetSystem` (owns `ClientNet` = one active `SocketHost`,
  connect to lobby, one-shot join/ready, roster trace). On `#if !sys` (web) it is a no-op stub.
- **No upper-level socket**: `HeapsApp` holds no `ClientNet`. Sockets live only in scene/room
  systems. `SceneManager.switchScene` calls `dispose()` on the previous scene (and drops it from
  the cache) → `BaseScene.dispose()` → `systems.clear()` releases the socket. Lobby→game later:
  lobby scene disposed (socket dropped), game scene creates its own socket on the room port.
- **System/Systems lifecycle**: `shared/systems/System.hx` gained `dispose()`, `Systems.clear()`
  and `removeByName()` call it. `BaseScene.dispose()` overrides `h3d.scene.Scene.dispose()`
  (`systems.clear()` + `animCtrl.clear()` + `super.dispose()`).

### Wire model — shared vs payload (`__isServer` decides RPC execution)

`rnl.net.NetworkSerializable` objects replicate (`@:s` dirty deltas, ADD/FULLSYNC/REMOVE) and
carry `@:rpc`. `rnl.net.Serializable` is a payload embedded inline in args/fields (no netId).

| Class | Shared? | Owner / `__isServer` | Purpose |
|---|---|---|---|
| `shared/net/LobbyNet.hx` | ✅ `NetworkSerializable` | **server** creates + `add()`s it | `@:rpc(server)` join/setReady/announce, `@:rpc(clients)` rosterChanged. 1 per lobby |
| `shared/net/PlayerInfo.hx` | ❌ `Serializable` | — | payload inside `rosterChanged(Array<PlayerInfo>)` |
| `shared/net/GameNet.hx` | ✅ `NetworkSerializable` | **server** creates + `add()`s it | game-room RPC facade: `@:rpc(server)` heroInput/fireBullet, `@:rpc(clients)` bulletSpawn/playerJoined/damage/bulletHit. 1 per game room |
| `shared/net/HeroObject.hx` | ✅ `NetworkSerializable` | **server** (created by `HeroSystem`) | per-player entity: `@:s` posX/Y/Z, yaw, hp/maxHp, weaponId, ammo, score — replicating DOWN via `__syncChannel=1` |

`__isServer` is set by the host: `add()` on server → `true`; receiving a mirror → accepting
side's role. **`@:rpc(server)` only executes where `__isServer==true`**, so server-RPCs require
server-owned objects. Coordinates of players are server-owned too (anti-cheat): server simulates,
writes `@:s x/y/z` into `HeroObject`, clients read the mirror; clients never own a `HeroObject`
for positions.

**LobbyNet client pattern** (don't create it client-side): the server owns it; the client
receives it as a mirror via FULLSYNC (`Type.resolveClass("shared.net.LobbyNet")` + instance) and
calls `mirror.join(name)`/`mirror.setReady(v)` (stubs → server) and receives `rosterChanged`
through the `onRoster` hook wired at mirror-up. Creating `LobbyNet` on the client would make it
client-owned → server wouldn't run its `@:rpc(server)` bodies (wrong `__isServer`) and you'd get
two facades. Client-owned objects are for per-player things later (e.g. a client's own weapon),
not for the lobby facade.

**Per-player entities (`HeroObject`) — a System owns the lifecycle, the room routes to the socket.**
`HeroSystem.spawnHero`/`removeHero` create/populate/release the `HeroObject` on the server
(`sim.isServer` guard), and the world map `sim.heroEnts` is the SINGLE storage (`SyncBridge` and
future systems read it there). The socket is owned by the room's `NetRoomSystem`, never the sim:
`DemoRoom` wires `heroSys.onNetSpawned = obj -> netSys.socket.add(obj)` and
`onNetRemoved = obj -> netSys.socket.remove(obj)`. The hooks are `#if sys` — on the client the
mirror arrives from the network (`GamePlayView.updateNet` writes it into `sim.heroEnts` for
`SyncBridge` reconciliation); the client never creates a `HeroObject`.

Rule of thumb — continuous per-player fields (`@:s`, e.g. `hp`) are written into the HeroObject
by the owning system; rnl replicates the dirty delta automatically. One-shot events (input, hits,
spawns) go through `@:rpc` on `GameNet`.

### rnl.net Registry CLID — must be seeded on BOTH ends (`NetRegistry`)

`rnl.net.Registry` fills lazily on `getCLID`. A peer that only RECEIVES a value-carrying
`Serializable` (e.g. `PlayerInfo` inside `rosterChanged`) never calls `getCLID` for it, so
`Registry.getClassName(clid)` returns null → deserialization crash
`Null access .bytes` in `LobbyNet.__rpcDispatch` (`rnl/net/Macros.hx`). Fix: 
`shared/net/NetRegistry.hx` (`init()` calls `Registry.getCLID` for `PlayerInfo`, `LobbyNet`,
`GameNet` and `HeroObject`), invoked in `ClientNet.new()` and `NetRoomSystem.new()`.

### hxml — models must survive DCE

`server.hxml` has `-D dce=no` + `--macro include("shared.net")`; `win.hxml` already uses
`-D dce=no`. ADD/FULLSYNC carry the class PATH string and the receiver does
`Type.resolveClass` — a DCE'd model class yields `ADD unknown class` and no RPC. Same classes
must compile on both ends (they live in `shared/`).

### Module naming gotcha

Haxe resolves a module by FILE name, not class name. `import shared.net.PlayerInfo` needs
`shared/net/PlayerInfo.hx` (it was `NetMessages.hx` first → `Type not found: shared.net.PlayerInfo`).
Keep one top-level class per file matching its name.

### `__rpcCaller` — hx_rnl patch (persistent, wiped on haxelib update)

Server RPC bodies can't see WHO invoked a `@:rpc` from the stock API. Applied patch in the
dev-checkout `D:/projects/pascal/rnl/hx_rnl/source/`:

- `rnl/net/NetworkSerializable.hx`: added `public var __rpcCaller:Int = -1;`
- `rnl/net/NetworkHost.hx` `receiveCall()`: set `obj.__rpcCaller = from.id;` before
  `obj.__receiveCall(image)` and reset to `-1` immediately after (RPC bodies run synchronously).

Server handlers read `netSys.net.__rpcCaller`. Used by `LobbyRoom.handleJoin` to map
`peerId → playerId`, so `onPeerDisconnect` can `leave()` the right player and broadcast the
updated roster to the others.

> **Wiped on hx_rnl update** (`haxelib update hxrnl` / `git pull` in the hx_rnl checkout) — same
> class of local patch as the heaps ones. Verify: `haxe server.hxml`; if `__rpcCaller` is missing,
> re-apply the two edits above.

### Connect timeout

`ClientNet` uses `haxe.Timer.stamp()` (wall clock, dt-independent): if no lobby mirror arrives
within `NetConfig.CONNECT_TIMEOUT_SECONDS` (5s) it traces
`CLIENT connect TIMEOUT: no server at 127.0.0.1:26260 within 5s — dropping socket`, disposes the
socket, sets `connectTimedOut`. No crash/hang; client keeps running offline.

### Current scope

Lobby + demo game room prototype: join/ready/roster (lobby, console traces); game room
(`DemoRoom`, port 1790) with per-player `HeroObject` coordinate replication (`SyncBridge`),
server-authoritative bullet hits (`SERVER HIT` verdict → `ShooterHit`/`VictimHit` on clients),
and puppet (de)spawn on join/disconnect (`HeroObject` REMOVE → client despawns the mirror hero).
`LobbyRoom` still auto-joins two demo players (`player-1`/`player-2`) in `ServerApp.main` —
visible in roster. Next: damage/HP (`HealthSystem` + cdb `damage` column + `gameNet.damage()`
RPC), weapon/ammo fields, `MapRoom` room kind, port pool `1790..1990`, `gameStart` handoff.

## Web target: resource (pak) loading

Web/JS has **no synchronous filesystem**, so `hxd.Res.initPak()` (which calls `sys.io.File.read` → `File.read not implemented`) must NEVER be called from `main()`. The black screen on first web runs was exactly this: `Main.main()` called `hxd.Res.initPak()`, threw on JS, and `HeapsApp.app()` never started (canvas stayed 300x150).

Correct pattern (already in place):
- `client/src/Main.hx` only calls `HeapsApp.app()`. Never call `hxd.Res.initPak()` from `main()` — it needs a synchronous filesystem and throws `File.read not implemented` on the JS/web target (black screen).
- `HeapsApp.loadAssets()` uses the **async** `hxd.fmt.pak.Loader(s2d, done)`, which on web fetches `res.pak` via `hxd.net.BinaryLoader` and on HL reads it synchronously. Works for both targets from one code path.
- The loader **hardcodes** the name `res.pak` (then `res1.pak`, …) and IGNORES the `-D resourcesPath` define. Location is relative to the HTML page on web, and relative to the **current working directory** on HL. If `res.pak` is missing, the loader traces an error and **hangs forever** (never calls `done()`) → black screen. So the pak MUST exist for both builds.

### Where the pak lives

- Web: `bin/web/res.pak` — next to `index.html`. Served over http.
- HL: `bin/client/res.pak` — next to `client.hl`. Because the loader resolves the path against the cwd, **run the client from its own folder**:
  ```sh
  cd bin/client && hl client.hl
  ```
  (Running `hl bin/client/client.hl` from the repo root would look for `./res.pak` at the root instead — don't.)

### `hxd.fmt.pak.Loader` — works, but mind its quirks

`hxd.fmt.pak.Loader` (`HeapsApp.loadAssets`) is the correct, working web-compatible loader for
both HL and web. It is **NOT broken** — the only thing that fails to compile in this checkout is
`hxd.fmt.hmd.Library` (see below), which the Loader does not use. The black screens were a usage
mistake (`hxd.Res.initPak()` from `main()`), not a Loader defect. Its sharp edges:

- **Hardcoded name, ignores `-D resourcesPath`.** It loads `res.pak`, then `res1.pak`, `res2.pak`…
  relative to the HTML page (web) / cwd (HL). The `resourcesPath` define is **not** consulted, so
  putting the pak at a `resourcesPath`-derived location will NOT be found.
- **Missing pak = permanent hang.** If `res.pak` is absent, it traces an error and never calls
  `done()` → `init()` never runs → canvas stays 300×150 (black screen). The pak MUST exist.
- **`initPak()` is the trap.** `hxd.Res.initPak()` (HL-only, synchronous `sys.io.File.read`) is what
  `Main.main()` originally called — it throws `File.read not implemented` on the JS/web target and
  was the original cause of the black screen. Never call it from `main()`; let `loadAssets` handle it.
- **Native read is synchronous/blocking.** On HL the `#if sys` branch does `sys.io.File.read("res.pak")`
  directly in `sync()` on the **main thread** — not a thread, not async I/O. For a tiny pak it's
  invisible (it happens before the first frame); for a huge pak it's a one-shot startup hitch.
  Web is genuinely async (`hxd.net.BinaryLoader`). Heaps' `hxd.res.Loader` does NOT make native
  loading async by itself — `load()` is synchronous.
- **Whole pak in RAM.** A `.pak` is one file; `addPak`/the Loader reads the entire file into a `Bytes`
  buffer at once, and all its raw resource bytes stay resident until the `FileSystem` is disposed.
  Splitting into `res`/`res1`/`res2` only helps if you load them on demand (or accept all-at-startup);
  splitting does NOT by itself limit memory unless you also control when paks are added/removed.

For on-demand named paks (e.g. `forest.pak`): read bytes (web `hxd.net.BinaryLoader`, native
`sys.io.File.getBytes`) and call `hxd.Res.loader.fs.addPak(new hxd.fmt.pak.FileSystem.FileInput(bytes))`;
after that `hxd.Res.load("forest/tree.png")` resolves from that pak. Stock `hxd.fmt.pak.FileSystem`
has no public per-pak unload — to reclaim memory you `fs.dispose()` and re-add what you still need.

### Building res.pak

`hxd.fmt.pak.Build` (the standard Heaps pak builder) works against this heaps-git checkout, but
only after a **one-line fix** to `hxd/fmt/hmd/Library.hx:268`. That line is the `#else` (non-neko)
branch:

```haxe
buf.vertexes = haxe.ds.Vector.fromData(vertexes.getNative());
```

`vertexes` is a `hxd.FloatBuffer`; `getNative()` returns `Array<hxd.impl.Float32>` (see
`hxd/FloatBuffer.hx:4`). But in **Haxe 4.3.7** `haxe.ds.Vector.VectorData<T>` is **not** `Array<T>`
on every target — it is `hl.NativeArray<T>` on HL, `neko.NativeArray<T>` on neko, `cs/java.NativeArray`
on cs/java (see `std/haxe/ds/Vector.hx`). `fromData` therefore wants e.g. `hl.NativeArray<Float32>`,
while `getNative()` yields a plain `Array<hxd.impl.Float32>` → type error on HL/neko/`--run`.
(On the **JS** target `VectorData` is `Array`, so it would compile there.) This is a
heaps-git × Haxe-4.3.x mismatch, not a local deviation — the upstream `HeapsIO/heaps` `master`
has the **exact same** un-casted line (`haxe.ds.Vector.fromData(vertexes.getNative())`); upstream
simply targets a Haxe where `VectorData == Array`. The fix is a single `cast` (works on all targets):
The fix is a single cast (works on all targets):

```diff
- buf.vertexes = haxe.ds.Vector.fromData(vertexes.getNative());
+ buf.vertexes = haxe.ds.Vector.fromData(cast vertexes.getNative());
```

This is **independent of `hxd.fmt.pak.Loader`** — the Loader never references `hmd`. The patch is
**currently APPLIED** in this environment's heaps-git checkout
(`C:/Users/simpl/scoop/apps/haxe/current/lib/heaps/git/hxd/fmt/hmd/Library.hx:268`), so the standard
`hxd.fmt.pak.Build` compiles and builds paks out of the box here (verified, produces `res.pak`):

```sh
haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/client/res
haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/web/res
# несколько групп за один запуск (имена res/res1/res2 чтобы Loader подхватил автоматом):
haxe -lib heaps --run hxd.fmt.pak.Build -res client/levels/forest -out bin/client/res1 -res client/levels/forest -out bin/web/res1
```

> **Re-applying after a heaps update.** The patch lives in the global heaps-git checkout
> (`C:/Users/simpl/scoop/apps/haxe/current/lib/heaps/git/hxd/fmt/hmd/Library.hx`), NOT in this
> repo, so `haxelib update heaps` / `git pull` inside heaps-git **wipes it**. After any heaps
> update, verify and restore it:
> 1. Compile the pak builder: `haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/client/res`
> 2. If it compiles → newer heaps already fixed it, nothing to do.
> 3. If it fails with exactly this error, the patch was wiped and must be re-applied:
>    `hxd/fmt/hmd/Library.hx:268: ... : hxd._FloatBuffer.InnerData should be haxe.ds._Vector.VectorData<Unknown<0>>`
>    Use the repo-contained helper (idempotent; safe to run even if unsure):
>    ```sh
>    haxe -lib heaps -hl tools/applypatch.hl -main ApplyHeapsPatch -cp tools
>    hl tools/applypatch.hl
>    ```
>    It rewrites the one-line cast at that line and prints `PATCH APPLIED` / `ALREADY PATCHED`.
>    (A newer heaps may also have changed the surrounding code — in that case the helper exits with
>    `PATCH TARGET NOT FOUND` and you re-read the function and apply an equivalent `cast`.)

#### domkit `h2d.domkit.Style.sync()` patch (local, re-apply after heaps update)
The `domkit` [git] currently checked out is NEWER than the `h2d.domkit.Style` in this heaps-git:
`Style.sync()` still calls `syncDirty(o.dom)`, a method that no longer exists in current domkit
(sync moved into `domkit.Properties.applyStyle(style, partialRefresh)`). This breaks compilation of
the entire `h2d.domkit` package. Fix — one line in
`C:/Users/simpl/scoop/apps/haxe/current/lib/heaps/git/h2d/domkit/Style.hx` (inside `sync()`):
```diff
- for( o in currentObjects )
-     syncDirty(o.dom);
+ for( o in currentObjects )
+     o.dom.applyStyle(this, true);
```
`domkit.CssStyle.TAG` and `updateTime(dt)` still exist, so only that call changes. `partialRefresh=true`
mirrors the old `syncDirty` (only re-applies when the object is dirty). Verified: both `linx.hxml`
and `web.hxml` compile after the change.
> **Wiped on heaps update.** Same as the `hmd` patch — `haxelib update heaps` / `git pull` in
> heaps-git removes it. If domkit UI stops compiling with `Unknown identifier : syncDirty`, re-apply
> the one-line edit above.

#### `tools/MakePak.hx` (redundant workaround — keep or delete)

Before the patch, a custom console builder `tools/MakePak.hx` was added to dodge the broken `hmd`
import (it uses only `hxd.fmt.pak.{Data,Writer,Reader}` + `sys.io`). It still works and has a
`-info <pak>` mode (via `hxd.fmt.pak.Reader`) that the standard Build lacks:

```sh
haxe -lib heaps -hl tools/makepak.hl -main MakePak -cp tools
hl tools/makepak.hl -res client/res -out bin/client/res
hl tools/makepak.hl -res client/res -out bin/web/res
hl tools/makepak.hl -info bin/web/res.pak
# PAK bin/web/res.pak  (version 0, header 51b, data 15b)
# > <root>  15b
#     placeholder.txt  15b
```

With the heaps patch already applied, the standard `hxd.fmt.pak.Build` is preferred; `MakePak` is
kept only for its `-info` inspector.


## Fonts (bitmap BMFont generation)

HUD text uses bitmap BMFonts (`client/res/font/<name>.fnt` + `<name>.png`) for Oswald/Inter, baked
at the exact pixel sizes the HUD needs. domkit `font:` entries in `LobbyView.LOBBY_CSS` reference them
as `font/<name>.fnt` (Heaps converts `.fnt`→`.bfnt` at load). One baked config per (family, weight,
size) is required because bitmap fonts are fixed-size.

- **Configs** (family, weight, size): `oswald 400/14`, `oswald 500/22`, `oswald 700/18`, `oswald 700/20`,
  `oswald 700/22`, `oswald 700/11`, `inter 400/18`, `inter 900/72`.
- **Character set**: ASCII 32–126 + Cyrillic U+0400–U+04FF (351 glyphs).
- **Atlas**: 2048×2048, single page.

### Canonical generator — `tools/makefonts.py` (Pillow + fontTools)
Supports full Unicode (incl. Cyrillic). Run from repo root:
```sh
python3 tools/makefonts.py
```
Writes `client/res/font/*.fnt` + `*.png`. It instances the variable TTFs (`tools/fonts_in/oswald.ttf`,
`tools/fonts_in/inter.ttf`) to a static TTF per (family, weight, size) via fontTools, then rasterizes
with PIL.

Gotchas that cost a day (do not regress):
- `ImageDraw.Draw(canvas).text(..., font=font, fill=255)` — the **`font=font` arg is REQUIRED**.
  Forgetting it silently draws PIL's default **6×8** bitmap font while `.fnt` metrics are computed
  from the real font → glyphs render microscopic but `lineHeight` looks correct.
- Instance cache filename MUST include `size` (not just family+weight): bold configs share a weight,
  and re-saving the same file while PIL holds it open → `Permission denied` → silent fallback to the
  raw variable font (regular weight, wrong). `makefonts.py` uses a fresh `tempfile.mkdtemp` per run
  to avoid locked-file reuse entirely.
- After regenerating fonts you must rebuild BOTH paks and BOTH targets (HL loads loose
  `client/res/` via `hxd.Res.initLocal()`, web uses the async pak loader — see Web target above):
  ```sh
  haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/client/res
  haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/web/res
  haxe win.hxml && haxe web.hxml
  ```

### Alternative — `tools/runnable-hiero.jar` (libGDX Hiero / FreeType)
Higher-quality hinting than PIL, but **cannot render non-Latin-1 characters**: Hiero reads
`glyph.text` as a single-byte charset, so any codepoint ≥256 (incl. Cyrillic, codepoint ≥1024) is
dropped from the atlas regardless of conf encoding (`utf-8`/`cp1251`) or `-Dfile.encoding`. Use Hiero
only for Latin-only fonts; for Cyrillic use `makefonts.py`.

Batch usage (needs a display/AWT; on headless it may hang on the AWT thread — always run with
`--batch` and kill the lingering `java` process afterwards, it does not self-exit reliably):
```sh
# write a .hiero config first — see tools/hiero/conf.hiero for a working sample / the key format
java -jar tools/runnable-hiero.jar --input conf.hiero --output outname --batch
# produces outname.fnt + outname1.png (+ outname2.png if it spills to more pages)
```
Hiero config keys of interest: `font2.file=<ttf>`, `font.size`, `font.bold`/`font.italic` (these only
toggle the style flag — for variable fonts, **pre-instance the weight to a static TTF** instead),
`glyph.text=<chars>`, `glyph.page.width/height` (use 2048), `render_type=0` (FreeType), and
`effect.class=...ColorEffect` / `effect.Color=ffffff` for plain white glyphs. Keep `glyph.text` on a
**SINGLE line** (multi-line breaks the parser with `ArrayIndexOutOfBoundsException`).


## Hide editor & `hide-plugin.js`

This is a hide project: the level prefabs (`client/res/levels/*.prefab`) are authored in the
hide scene editor, and the game view loads the prefab via `hrt.prefab` under `#if hide`
(HL-only; the web build is procedural). Two pieces have to be generated:

- **The hide editor itself** — wrapped as an NW.js app at `D:\projects\haxe\windows\hide.cmd`
  (web/JS build of hide; opens Chromium with `--remote-debugging-port=9222`). Launch it with
  `D:\projects\haxe\windows\hide.cmd`, then **Open** the project: pick the `client` folder
  (or `client/hide-plugin.hxml`). Resources are `client/res`.
- **The project plugin** — the editor is vanilla hide; game-specific editor code (custom
  prefab classes/properties) lives in `client/hide-plugin.hxml` and must be compiled to JS:

```sh
haxe --cwd client client/hide-plugin.hxml   # -> client/hide-plugin.js (+ .map)
```

The hxml uses `-js hide-plugin.js` and `-cp src`, so **always run it with `--cwd client`**
(`-cp`/`-js` in hxml resolve against the working directory, NOT the hxml location — verified).
It links `-lib hide/hxnodejs/domkit`, `--macro hide.Plugin.init()`, `-D script`. A rebuild is
idempotent (`git status` stays clean on the existing `client/hide-plugin.js`).

Plugins are registered per-project in `client/res/props.json`:
`{ "plugins": ["../hide-plugin.js"] }`. `loadPlugin` resolves the path relative to the resource
dir (`client/res`), so `../hide-plugin.js` → `client/hide-plugin.js`. The plugin file is
file-watched — regenerate it while hide is open and it hot-reloads.

Workflow: `haxe --cwd client client/hide-plugin.hxml` → start `hide.cmd` → Open `client` →
open `client/res/levels/test.prefab` in the Scene tab → edit → save (writes the `.prefab`),
then rebuild the paks + win target to see it in-game.

## Game data — castle/cdb (`res/db/data.cdb`)

Starter data-driven config lives in `client/res/db/data.cdb` (castle/cdb format —
plain JSON; `cdb.Parser` maps the numeric `typeStr` to `cdb.Data.ColumnType`:
0=TId, 1=TString, 3=TInt, 4=TFloat…). One file, meant to be shared: the client reads it
via `client/src/extract/utils/GameData.hx` (`hxd.Res.load("db/data.cdb").toText()`
→ `GameData.fromCdb`), the headless server can later use the SAME parser with
`sys.io.File.getContent` (cdb has no heaps dependency). Client builds link cdb via
`-lib castle` in `win.hxml`/`web.hxml`.

### Regenerating the starter DB — `tools/GenDb.hx`

```sh
haxe -lib castle -hl tools/gendb.hl -main GenDb -cp tools
hl tools/gendb.hl                # writes client/res/db/data.cdb
hl tools/gendb.hl -out <path>    # custom output path
```

Idempotent: builds the `World` and `Hero` sheets (World columns: id/floorHalf/cubeSize/
cubeSpawnInterval/gravityY; Hero columns: id/heroRadius/heroHalfHeight), serializes with
`db.save()`, then re-loads the written file and prints the values (round-trip self-check).
After any schema change → re-run the tool AND rebuild both paks + both targets (web reads
`db/data.cdb` from the pak):

```sh
haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/client/res
haxe -lib heaps --run hxd.fmt.pak.Build -res client/res -out bin/web/res
haxe win.hxml && haxe web.hxml
```

> **GenDb only builds World + Hero.** The Camera, Controller, and Bullet sheets
> (see "Current cdb sheets" below) were added by hand-editing `data.cdb` directly.
> If GenDb is re-run, it will overwrite the file — re-add those sheets afterward.

Gotchas:
- castle `Sheet.newLine()` crashes on an empty sheet (`lines[-1]`, `Sheet.hx:215`) —
  GenDb pushes directly into the public `sheet.lines` instead.
- Column literals must use `typeStr : null` (NOT `""`): `Parser.save()` only fills
  `typeStr` when it is null, and `""` round-trips into "Unknown type" on load.
- `GameData.req()` / `GameData.reqB()` throw a **hard error** at startup when the
  file, sheet, or field is missing — no silent fallback to `Config.hx` defaults.
  This is intentional: missing cdb data = broken data = fail-fast.
- hide's Data tab is not wired up yet (would need `cdb.databaseFile` project config
  pointing at `res/db/data.cdb`); for now the file is authored by GenDb + manual edits.

## Architecture

### Core principle: shared simulation, client/server split

`shared/src/shared/SimWorld.hx` is THE simulation — run identically by client
(`client/src/extract/views/GamePlayView.hx`) and server (`server/src/serv/ServerApp.hx`).
Gameplay rules (auto-spawn cubes, level geometry) live in SimWorld or shared systems, never
in client/server code.

`SimWorld.isServer` (from the ctor `server` param) tells systems which side they are:
true on the headless server (authority — owns net objects, emits hit verdicts), false on
every client and on web (where the whole net layer is `#if sys`'ed out).

Consumers hook in via `IPhysicsConsumer`: client attaches `phys.render.PhysRenderer` (with
`sim.physCore` for interpolation); server attaches a `StateLogger`. The server must never
link heaps or define `-D heapsphysics_render` (that define gates `phys/render/*`, which needs h3d).

### Entity factory — the only spawn path

`IEntityFactory` (shared interface) → `BaseEntityFactory` (shared recipes: `createWorld`,
`spawnLevel`, `spawnCube`, `spawnHeroBody`, `spawnBulletBody`). Side implementations:
`server/src/serv/factory/ServerEntityFactory` (headless — lifecycle hooks are no-ops) and
`client/src/extract/factory/ClientEntityFactory` (binds a mesh in `onBodyAdded` via the
PhysRenderer and exposes `localHeroMesh` as the camera anchor).

Bodies are spawned ONLY through `sim.factory.spawnX` and then registered via `sim.add(b)` /
`sim.setHero(pid, b)` — that is what fires `factory.onBodyAdded` (client: mesh up; server:
no-op). `sim.buildLevel()` spawns the level; on the client it MUST run after
`factory.bindRenderer(physRenderer)`, or level meshes never bind.

Why two classes: the recipes are pure physics and shared (identical client+server = the
deterministic sim); `meshForBody` builds h3d meshes and therefore lives in the client factory
only — it must NOT be in the shared interface, or the headless server build would pull in heaps.

**Creation order in GamePlayView**: `factory = new ClientEntityFactory(this)` →
`sim = factory.createWorld(gd, bus, false)` → `physRenderer = new PhysRenderer(sim.physCore)`
→ `sim.phys.addConsumer(physRenderer)` → `factory.bindRenderer(physRenderer)` →
`sim.buildLevel()` → `heroSys.spawnHero(Player.LOCAL)` → `player.mesh = factory.localHeroMesh`.

### Systems & EventBus

All gameplay logic is split into isolated `System` subclasses (`shared/systems/System.hx`),
held by a `Systems` container inside `SimWorld`. Systems communicate only through the
`EventBus` (`shared/events/EventBus.hx`) — no direct system-to-system references. A system
may read/write WORLD state (`sim.heroes`, `sim.heroEnts`, physics) freely; it may not reach
into another system or the room's socket.

**Sim systems** (shared, run on client and server alike):
- `HeroSystem` — per-player hero capsules; subscribes to `HeroMoveIntent`; applies velocity
  easing, yaw, ground check, jump lock via `HeroState` typedef keyed by `playerId`. On the
  server it ALSO owns the per-player `HeroObject` lifecycle (see "Per-player entities" under
  Networking). Input vs output: `states` (`Map<String, HeroState>`) is the per-player INPUT
  snapshot (dirX/dirZ/yaw/mag + jump lock) — local to each sim, NEVER replicated; `HeroObject`
  is the OUTPUT (position/HP/weapon) — replicated. Pipeline: states → `apply()` → physics body
  → SyncBridge → HeroObject → clients.
- `BulletSystem` — subscribes to `BulletFired`; spawns `SphereGeometry` projectiles with
  `setGravityScale(0)`, collision layer BULLET→WORLD; deferred removal (safe outside solver).
  On the server (`sim.isServer`) it is the authoritative hit detector: publishes `BulletHit`
  verdicts (ownerId, victimId, impact point) that `ServerTransportSystem` broadcasts.

**Client systems** (`client/src/extract/systems/`):
- `PlayerControllerSystem` — composes `CameraController` (look) + `MovementController` (WASD);
  publishes `HeroMoveIntent(Player.LOCAL, ...)` and `BulletFired` to the bus; ESC toggles
  freeLook/cursor; `followRate = 150` filters 30Hz wobble without perceptible lag

### Player identity

`shared/Player.hx`: `Player.LOCAL = "local"` constant. `SimWorld.heroes: Map<String, PhysBody>`
holds all hero bodies keyed by playerId. `sim.hero` is a convenience getter returning
`heroes[LOCAL]`. `sim.heroEnts: Map<String, HeroObject>` (under `#if sys`) holds the per-player
net entities — server: owned objects, client: mirrors written by `GamePlayView.updateNet`.

### Collision layers (`shared/Collision.hx`)

Structural constants, not cdb tunables — identical on client and server for determinism:
- `HERO = 1`, `WORLD = 2`, `BULLET = 4`, `ALL = HERO|WORLD|BULLET`
- Bullets (mask=WORLD) hit cubes/floor but not the shooter's hero
- All world geometry uses `setGroup(WORLD).setMask(ALL)`

### Body types

Extend by adding a case in `ClientEntityFactory.meshForBody()` (keyed by body name string),
a shared recipe in `BaseEntityFactory`, AND corresponding spawn logic in `SimWorld` or a system.
Current body names: `"floor"`, `"cube"`, `"hero"`, `"bullet"`.

### Tunables

ALL gameplay tunables live in `client/res/db/data.cdb` (castleDB format — see
"Game data" section). Code reads them via `GameData.req(sheet, field)` which throws a
clear error at startup when a field is missing (fail-fast, no silent defaults).
`shared/Config.hx` only holds fixed structural constants (`PHYSICS_HZ = 30`,
`SERVER_RUN_SECONDS = 15`).

### Physics

- Fixed 30 Hz tick (`Config.PHYSICS_HZ`); rendering interpolated via `PhysCore.interpol`
- Physics world is Y-up; Heaps camera defaults to Z-up — `camera.up.set(0,1,0)` in HeapsApp
- `SimWorld.add(b)` is the mandatory spawn path: it fires `factory.onBodyAdded(b)`, which is
  what creates/binds the client mesh (`ClientEntityFactory`); `phys.spawnBody()` without
  `sim.add()` never reaches the client view

### Extending the prototype — recipes

**New shared sim system** (runs on both ends, e.g. next `HealthSystem`):
1. `class HealthSystem extends shared.systems.System` — ctor `super(bus, sim, gd, "Health")` +
   `bus.subscribe(...)`; rules run in `update(dt)`, world mutation via `sim` only.
2. Register in `SimWorld` ctor: `systems.add(new shared.systems.HealthSystem(bus, this, gd));`.
3. Server-only net write: guard `#if sys if (sim.isServer)` and write straight into
   `sim.heroEnts[pid]` `@:s` fields (automatic dirty replication). The room never touches
   entity data — it only routes objects to the socket (`onNetSpawned`/`onNetRemoved`).
4. Tunables via `gd.req("Sheet", "field")` (fail-fast on missing) — add the column to
   `client/res/db/data.cdb` (hand-edit; `GenDb.hx` only builds World+Hero — re-add the rest).

**New `@:rpc` on GameNet**: add a handler field (`onX : Null<... -> Void>`) + a `@:rpc(server)`
/`@:rpc(clients)` method; wire the handler on the matching `__isServer` side (room sets the
server-side ones, client `RoomNetSystem`/`ServerTransportSystem` the client-side ones). If a NEW
`Serializable`/model type reaches a receiver as RPC arg or `@:s` field, reseed `NetRegistry` with
it (CLID must exist on both ends).

**New spawnable body**: recipe in `BaseEntityFactory` (`spawnXBody`) + mesh case in
`ClientEntityFactory.meshForBody` (name string must match) + spawn call in SimWorld/system through
`sim.factory` — never inline.

## Current cdb sheets

`client/res/db/data.cdb` — five sheets, all with a single `"default"` row:

| Sheet | Columns (typeStr) | Default values | Purpose |
|---|---|---|---|
| **World** | `id:0`, `floorHalf:4`, `cubeSize:4`, `cubeSpawnInterval:4`, `gravityY:4` | 10, 1, 2, -9.80665 | Level geometry, physics constants |
| **Hero** | `id:0`, `heroRadius:4`, `heroHalfHeight:4`, `speed:4`, `jumpVelocity:4`, `groundProbe:4` | 0.4, 0.45, 6, 5.5, 0.12 | Capsule dimensions, movement |
| **Camera** | `id:0`, `sensitivity:4`, `fov:4`, `maxPitch:4`, `lookSmooth:4`, `invertX:1`, `invertY:1`, `eyeHeight:4` | 0.002, 75, 1.5533, 25, true, false, 1.6 | FPS camera params |
| **Controller** | `id:0`, `moveSmooth:4`, `stopSmooth:4`, `stopThreshold:4`, `fastMult:4`, `invertX:1`, `invertZ:1` | 12, 20, 0.05, 2, true, false | WASD input smoothing |
| **Bullet** | `id:0`, `radius:4`, `speed:4`, `cooldown:4`, `lifetime:4` | 0.15, 25, 0.25, 10 | Projectile params |

> **Planned**: add `damage:4` (TFloat, default ~25) to the Bullet sheet for `HealthSystem`
> (server: `HeroObject.hp -= damage` on hero-hit, rnl replicates the dirty delta; the instant-UI
> `gameNet.damage()` RPC is a separate channel — see "Extending" recipes above).

Type codes: `0=TId`, `1=TBool`, `4=TFloat`.

**Important**: `GenDb.hx` only rebuilds **World + Hero**. Camera/Controller/Bullet were
added manually — re-running GenDb overwrites the file and loses them.

## Rigged character models (FBX import gotchas)

Game-rip/sketchfab FBX characters (e.g. `WXBFESKTTRF6UPB2DELL0KE3F_Rigged`) import into
Heaps looking **long / thin / flat / lying on a side**. Three independent causes — the first two
are exporter bugs in the files themselves, the third is scale:

1. **Broken inverse-bind matrices (the "skeleton stretches the model" case).** The FBX cluster
   `Transform` matrices don't match the joint hierarchy, so in the converted HMD
   `transPos * bindWorld != identity` (checked in `tools` probes: palettes had ~120-unit
   translations and near-zero rotation rows). Result: the mesh deforms into a long thin figure.
   **Fix** (`GamePlayView.fixSkinBind`, runtime, no heaps edits): recompute each joint's
   `transPos` as the exact inverse of its bind world matrix — `inverse(defMatChain * skinDefaultWorld)`,
   where `defMatChain` is the bind-pose world (recursive over `h3d.anim.Skin.Joint.parent`) and
   `skinDefaultWorld` is the product of `h3d.scene.Object.defaultTransform` from the model root
   down to the skin. With that, the bind palette is identity and the mesh keeps its shape.

2. **Baked 90° rotation on the mesh node.** The `LoadedModel` FBX node carries a `q=(0.7071,0,0)`
   rotation, so the character imports **lying down**. Heaps applies it via the skin's
   `defaultTransform`. **Fix**: counter-rotate the model object (`model.rotate(...)`) until it
   stands; sign/axis depends on the file — `rotate(0,0,Math.PI/2)` stood this one up. Check for
   upside-down/back-facing and flip the sign.

3. **Native size ≠ game units.** These models are ~3.75 world units tall (the hero capsule is
   1.7). **Fix**: `model.setScale(0.45)` ≈ hero height.

Diagnosis tool: `h3d.prim.ModelCache` is used in `client/src/extract/models/PlayerModel.hx`
(`fixSkinBind` is currently commented out there); a headless probe
(`tools` or temp) that runs `hxd.fmt.fbx.Parser` → `HMDOut.toHMD` → `hxd.fmt.hmd.Writer/Reader`
round-trip and prints per-joint `transPos * bindWorld` palettes shows immediately whether a model
needs the bind fix.

> **`deepCopyMaterial` heaps patch (required to load ANY hmd model under PBR).** `hxd/fmt/hmd/Library.hx`
> `deepCopyMaterial` crashes with `Null access` in `h3d.mat.PbrMaterial.resetProps` when `props`
> is assigned before the cloned material's `mainPass` exists (the `@:bypassAccessor` does not
> bypass the overridden `set_props` here). Applied fix: move `m.props = src.props;` to the END of
> `deepCopyMaterial`, after the passes are cloned. Same class of local patch as the `hmd`/domkit
> ones above — **wiped on heaps update**, re-apply after `haxelib update heaps`.

## Misc

- Root `js_imports.txt` / `js_externs.txt` / `js_exports.txt` are reference dumps of the Oimo JS API (from oimophysics's JS export); not part of any build, gitignored.
