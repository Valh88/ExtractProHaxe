# AGENTS.md

Haxe/HashLink physics demo built on the local `HeapsPhysics` haxelib (`phys.*`, wraps Oimo). No package.json, no tests, no CI — verification = both targets compile + headless server runs.

## Build & run

hxml files live at repo root; output goes to gitignored `bin/`.

```sh
haxe linx.hxml      # client -> bin/client/client.hl
hl bin/client/client.hl   # opens a window

haxe server.hxml    # headless server -> bin/server/serv.hl
hl bin/server/serv.hl     # runs ~15s then exits (Config.SERVER_RUN_SECONDS)
```

- Both hxml hard-code `-cp /home/vano/.haxe_lib/oimophysics/git/src` — an absolute path to a dev-machine checkout; builds fail anywhere else until this is fixed.
- Deps are dev-installed haxelibs: `heapsphysics` (provides `phys.*`), `oimophysics`, `heaps`, `format`.
- Client build emits many `(WDeprecated) @:extern` warnings from oimophysics — harmless, not errors.

## Architecture

- `shared/src/shared/SimWorld.hx` is THE simulation, run identically by client (`client/src/extract/HeapsApp.hx`) and server (`server/src/serv/ServerApp.hx`). Gameplay rules (auto-spawn cubes, level geometry) go in SimWorld, not in client/server code.
- Consumers hook in via `IPhysicsConsumer`: client attaches `phys.render.PhysRenderer`; server attaches a `StateLogger`. The server must never link heaps or define `-D heapsphysics_render` (that define gates all of `phys/render/*`, which needs h3d).
- New body types: extend `meshForBody()` switch in HeapsApp (keyed by body name string like "floor"/"cube") AND spawn logic in SimWorld.
- Tunables are inline constants in `shared/src/shared/Config.hx` (fixed 30 Hz tick, gravity, spawn interval).
- Physics world is Y-up; Heaps camera defaults to Z-up, hence the explicit `camera.up.set(0,1,0)` in HeapsApp.

## Misc

- Root `js_imports.txt` / `js_externs.txt` / `js_exports.txt` are reference dumps of the Oimo JS API (from oimophysics's JS export); not part of any build, gitignored.
