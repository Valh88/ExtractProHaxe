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
".mode-panel { position:absolute; width:300; height:460; background:#1A1208; }",
".ready-panel { position:absolute; width:600; height:190; background:#1A1208; }",
".mode-title { position:absolute; color:#C4A44A; }",
".duration { position:absolute; color:#6A5A3A; }",
".map-image { position:absolute; width:180; height:120; background:#2A1A10; }",
".mode-icon-solo { position:absolute; width:56; height:56; background:#2A1A10; }",
".mode-icon-party { position:absolute; width:56; height:56; background:#1A1208; }",
".mode-icon-label { position:absolute; color:#D8B98A; }",
".mode-icon-party .mode-icon-label { color:#6A5A3A; }",
".search-button { position:absolute; width:180; height:50; background:#8B2010; }",
".search-text { position:absolute; color:#F0E0D0; }",
".ready-title { position:absolute; color:#BFBFBF; }",
".player-chip { position:absolute; width:72; height:104; background:#1A1208; }",
".chip-icon { position:absolute; x:12; y:10; width:48; height:48; background:#2A1A10; }",
".player-status { position:absolute; color:#BFBFBF; }",
".player-chip-ready .player-status { color:#1ACC19; }",
".player-chip-waiting .player-status { color:#B3B319; }",
".player-chip-notready .player-status { color:#B33333; }",
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
