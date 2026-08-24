# AGENTS.md

Haxe/HashLink physics demo built on the local `HeapsPhysics` haxelib (`phys.*`, wraps Oimo). No package.json, no tests, no CI — verification = both targets compile + headless server runs.

## Build & run

hxml files live at repo root; output goes to gitignored `bin/`.

```sh
haxe linx.hxml      # client -> bin/client/client.hl
hl bin/client/client.hl   # opens a window

haxe web.hxml       # client -> bin/web/game.js  (HTML5 / WebGL2 target)
                     # serve bin/web/ over http (file:// will not load resources)

haxe server.hxml    # headless server -> bin/server/serv.hl
hl bin/server/serv.hl     # runs ~15s then exits (Config.SERVER_RUN_SECONDS)
```

- Both hxml hard-code `-cp /home/vano/.haxe_lib/oimophysics/git/src` — an absolute path to a dev-machine checkout; builds fail anywhere else until this is fixed. `web.hxml` overrides it on the next line with a local `-cp D:/projects/haxe/OimoPhysics/src`; the stale Linux line should be deleted.
- Deps are dev-installed haxelibs: `heapsphysics` (provides `phys.*`), `oimophysics`, `heaps`, `format`.
- Client build emits many `(WDeprecated) @:extern` warnings from oimophysics — harmless, not errors.

## Web target: resource (pak) loading

Web/JS has **no synchronous filesystem**, so `hxd.Res.initPak()` (which calls `sys.io.File.read` → `File.read not implemented`) must NEVER be called from `main()`. The black screen on first web runs was exactly this: `Main.main()` called `hxd.Res.initPak()`, threw on JS, and `HeapsApp.app()` never started (canvas stayed 300x150).

Correct pattern (already in place):
- `client/src/Main.hx` only calls `HeapsApp.app()`.
- `HeapsApp.loadAssets()` uses the **async** `hxd.fmt.pak.Loader(s2d, done)`, which on web fetches `res.pak` via `hxd.net.BinaryLoader` and on HL reads it synchronously. Works for both targets from one code path.
- The loader expects `res.pak` next to `index.html` (i.e. `bin/web/res.pak`). If it is missing, the loader traces an error and **hangs forever** (never calls `done()`) → black screen. So the pak MUST exist for the web build.

### Building res.pak (new method)

The standard `haxe -lib heaps --run hxd.fmt.pak.Build` does NOT compile against the current
heaps-git checkout — it fails with `hxd._FloatBuffer.InnerData should be haxe.ds._Vector.VectorData`
in `hxd/fmt/hmd/Library.hx` (a heaps-git vs Haxe version mismatch, pulled in only by the model
conversion path). Instead use the small custom builder:

```sh
haxe -lib heaps -hl tools/makepak.hl -main MakePak -cp tools
hl tools/makepak.hl          # bundles client/res/* into bin/web/res.pak
```

`tools/MakePak.hx` only touches `hxd.fmt.pak.{Data,Writer}` + `sys.io`, avoiding the broken
`hmd` import. It walks `client/res/`, packs every file (skipping dotfiles) into `bin/web/res.pak`.
After changing assets in `client/res/`, re-run `hl tools/makepak.hl`.


## Architecture

- `shared/src/shared/SimWorld.hx` is THE simulation, run identically by client (`client/src/extract/HeapsApp.hx`) and server (`server/src/serv/ServerApp.hx`). Gameplay rules (auto-spawn cubes, level geometry) go in SimWorld, not in client/server code.
- Consumers hook in via `IPhysicsConsumer`: client attaches `phys.render.PhysRenderer`; server attaches a `StateLogger`. The server must never link heaps or define `-D heapsphysics_render` (that define gates all of `phys/render/*`, which needs h3d).
- New body types: extend `meshForBody()` switch in HeapsApp (keyed by body name string like "floor"/"cube") AND spawn logic in SimWorld.
- Tunables are inline constants in `shared/src/shared/Config.hx` (fixed 30 Hz tick, gravity, spawn interval).
- Physics world is Y-up; Heaps camera defaults to Z-up, hence the explicit `camera.up.set(0,1,0)` in HeapsApp.

## Misc

- Root `js_imports.txt` / `js_externs.txt` / `js_exports.txt` are reference dumps of the Oimo JS API (from oimophysics's JS export); not part of any build, gitignored.
