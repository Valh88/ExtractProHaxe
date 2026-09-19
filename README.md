# ExtractPro

Haxe/Heaps physics demo: an FPS playground (`extract.*`) driven by a shared deterministic
simulation (`shared.*`) running identically on the client and the headless server, plus a
multiplayer prototype over RNL/UDP (HL only). Physics comes from the local `HeapsPhysics`
haxelib (wraps Oimo). Details in [AGENTS.md](AGENTS.md).

## Build

No package.json, no tests, no CI. Verification = both targets compile + headless server runs.

```sh
haxe win.hxml       # HL client -> bin/client/client.hl
hl bin/client/client.hl

haxe web.hxml       # JS client -> bin/web/game.js  (serve bin/web/ over http)
haxe server.hxml    # headless server -> bin/server/serv.hl

haxe --cwd client client/hide-plugin.hxml   # hide editor plugin -> client/hide-plugin.js
```

## Run notes

- Run the HL client from its own folder (`cd bin/client && hl client.hl`) so `res.pak` resolves.
- The web target has no UDP — networking is stubbed with `#if sys`.
- RNL native libs (`rnl.hdll`, `RNL.dll`) must sit next to the `.hl`; re-copy after a clean
  checkout from `D:/projects/pascal/rnl/hx_rnl/ndll/win64/`.

## Layout

- `client/` — Heaps presentation + UI, client-side systems, resources (pak), fonts, level prefabs.
- `server/` — headless server app (same sim, `StateLogger` instead of rendering).
- `shared/` — the sim (`SimWorld`), systems, EventBus, replication (`SyncBridge`), net models.
- `tools/` — font baking, cdb generation, pak utilities, heaps patch helper.
- `hxml` files at root: `win.hxml`, `web.hxml`, `server.hxml`, `netclienttest.hxml`.

The `template` branch accumulates self-contained reusable modules for other projects
(see the "Template branch" section of AGENTS.md).

## Game data

Tunables live in `client/res/db/data.cdb` (castle/cdb) and are read via `GameData.req()` —
missing data fails fast at startup. Regenerate starter sheets with `tools/GenDb.hx`.