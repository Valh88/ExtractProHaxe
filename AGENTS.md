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


## Architecture

- `shared/src/shared/SimWorld.hx` is THE simulation, run identically by client (`client/src/extract/HeapsApp.hx`) and server (`server/src/serv/ServerApp.hx`). Gameplay rules (auto-spawn cubes, level geometry) go in SimWorld, not in client/server code.
- Consumers hook in via `IPhysicsConsumer`: client attaches `phys.render.PhysRenderer`; server attaches a `StateLogger`. The server must never link heaps or define `-D heapsphysics_render` (that define gates all of `phys/render/*`, which needs h3d).
- New body types: extend `meshForBody()` switch in HeapsApp (keyed by body name string like "floor"/"cube") AND spawn logic in SimWorld.
- Tunables are inline constants in `shared/src/shared/Config.hx` (fixed 30 Hz tick, gravity, spawn interval).
- Physics world is Y-up; Heaps camera defaults to Z-up, hence the explicit `camera.up.set(0,1,0)` in HeapsApp.

## Misc

- Root `js_imports.txt` / `js_externs.txt` / `js_exports.txt` are reference dumps of the Oimo JS API (from oimophysics's JS export); not part of any build, gitignored.
