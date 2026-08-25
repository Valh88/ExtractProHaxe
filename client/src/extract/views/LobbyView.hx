package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;

/**
	Root scene of the whole lobby. Extends the 3D scene so all 3D models
	are rendered here; the 2D domkit HUD (Lobbydesign) is attached on top
	via the 2D scene, and `update` drives the domkit style sync.
**/
class LobbyView extends Scene3D
{
	var style : Style;

	// Mirror of client/res/ui/lobby.css (kept in sync by hand). Parsed inline
	// because reading text entries out of res.pak fails on HL (seek2 failure).
	static var LOBBY_CSS = [
".lobby-root {}",
".top-panel { position:absolute; width:1920; height:70; background:#1A1208; }",
".top-border { position:absolute; width:1920; height:2; background:#C8956C; }",
".gold-group { position:absolute; }",
".gold-icon { position:absolute; width:30; height:30; background:#D4A574; }",
".gold-amount { position:absolute; color:#BFBFBF; }",
".menu-tabs { position:absolute; }",
".tab { position:absolute; color:#737373; }",
".tab-active { color:#BFBFBF; }",
".right-icons { position:absolute; }",
".slot { position:absolute; width:40; height:40; background:#2A1A10; }",
".slot-main { background:#3A2A18; }",
".icon { position:absolute; width:40; height:40; background:#404040; }",
".bottom-panel { position:absolute; width:1920; height:70; background:#1A1208; }",
".bottom-gradient { position:absolute; width:1920; height:140; background:#000000 0.7; }",
".hunt-title { position:absolute; color:#C4A44A; }",
".subtitle { position:absolute; color:#6A5A3A; }",
	].join("\n");

	public function new()
	{
		super();
		// physics is Y-up, Heaps camera defaults to Z-up
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);
		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, -0.4, -1), this);
		light.power = 2;
	}

	/** Attach the 2D domkit HUD (built by Lobbydesign) onto the 2D scene. */
	public function attachUI(design : Lobbydesign, s2d : Scene2D)
	{
		style = new Style();
		// CSS is parsed from an embedded string: reading text entries out of
		// res.pak currently fails on HL (seek2 failure), so we don't load it
		// through hxd.res. The canonical copy still lives in client/res/ui/lobby.css.
		style.add(style.cssParser.parseSheet(LOBBY_CSS, "ui/lobby.css"));
		s2d.addChild(design);
		style.addObject(design);
		style.sync();
	}

	/** Add a 3D model into the lobby scene. */
	public function addModel(o : h3d.scene.Object)
	{
		this.addChild(o);
	}

	/** Per-frame update. Drives the domkit style sync (animations / live reload). */
	public function update(dt : Float)
	{
		style.sync(dt);
	}
}
