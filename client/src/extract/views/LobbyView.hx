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
	// rather than from a resource file so the CSS stays part of the source tree.
	static var LOBBY_CSS = [
".lobby-root {}",
".top-panel { position:absolute; width:1920; height:70; background:#1A1208; }",
".top-border { position:absolute; width:1920; height:2; background:#C8956C; }",
".gold-group { position:absolute; }",
".gold-icon { position:absolute; width:30; height:30; background:#D4A574; }",
".gold-amount { position:absolute; color:#BFBFBF; font: font/oswald_bold_18.fnt; }",
".menu-tabs { position:absolute; }",
".tab { position:absolute; }",
".tab-idle { color:#737373; font: font/oswald_medium_22.fnt; }",
".tab-active { color:#BFBFBF; font: font/oswald_bold_22.fnt; }",
".right-icons { position:absolute; }",
".slot { position:absolute; width:40; height:40; background:#2A1A10; }",
".slot-main { background:#3A2A18; }",
".icon { position:absolute; width:40; height:40; background:#404040; }",
".bottom-panel { position:absolute; width:1920; height:70; background:#1A1208; }",
".bottom-gradient { position:absolute; width:1920; height:140; background:#000000 0.7; }",
".hunt-title { position:absolute; color:#C4A44A; font: font/inter_black_72.fnt; }",
".subtitle { position:absolute; color:#6A5A3A; font: font/inter_regular_18.fnt; }",
// --- ModePanel (PanelBG) ---
".mode-panel { position:absolute; width:300; height:460; background:#C8956C; }",
".mode-inner { position:absolute; width:296; height:456; background:#1A1208; }",
".mode-title { position:absolute; width:88; height:27; color:#C4A44A; font: font/oswald_bold_18.fnt; text-align:center; }",
".map-image { position:absolute; width:180; height:120; background:#2A1A10; }",
".duration { position:absolute; width:32; height:21; color:#6A5A3A; font: font/oswald_regular_14.fnt; text-align:center; }",
".mode-icons { position:absolute; width:130; height:56; }",
".solo-icon { position:absolute; width:56; height:56; background:#2A1A10; }",
".party-icon { position:absolute; width:56; height:56; background:#1A1208; }",
".solo-label { position:absolute; width:8; height:30; color:#C4A44A; font: font/oswald_bold_20.fnt; text-align:center; }",
".party-label { position:absolute; width:11; height:30; color:#6A5A3A; font: font/oswald_bold_20.fnt; text-align:center; }",
".search-btn { position:absolute; width:180; height:50; background:#8B2010; }",
".search-text { position:absolute; width:59; height:27; color:#C4A44A; font: font/oswald_bold_18.fnt; text-align:center; }",
// --- ReadyPanel (CheckReadingDesign) ---
".ready-panel { position:absolute; width:600; height:190; background:#C8956C; }",
".ready-inner { position:absolute; width:596; height:186; background:#1A1208; }",
".ready-title { position:absolute; width:48; height:27; color:#BFBFBF; font: font/oswald_bold_18.fnt; text-align:center; }",
".player-group { position:absolute; width:236; height:104; }",
".chip { position:absolute; width:72; height:104; }",
".status { position:absolute; width:72; height:14; text-align:center; font: font/oswald_bold_11.fnt; }",
".chip-ready .status { color:#1ACC19; }",
".chip-waiting .status { color:#B3B319; }",
".chip-notready .status { color:#B33333; }",
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
