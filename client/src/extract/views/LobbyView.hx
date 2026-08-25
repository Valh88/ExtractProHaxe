package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;
import extract.views.CSS;
/**
	Root scene of the whole lobby. Extends the 3D scene so all 3D models
	are rendered here; the 2D domkit HUD (Lobbydesign) is attached on top
	via the 2D scene, and `update` drives the domkit style sync.
**/
class LobbyView extends Scene3D
{
	var style : Style;
	var s2d : Scene2D;

	// Mirror of client/res/ui/lobby.css (kept in sync by hand). Parsed inline
	// rather than from a resource file so the CSS stays part of the source tree.
	static var LOBBY_CSS = CSS.LOBBY_CSS;

	public function new(s2d : Scene2D)
	{
		super();
		this.s2d = s2d;
		h3d.Engine.getCurrent().backgroundColor = 0x0D0D0D;
		// physics is Y-up, Heaps camera defaults to Z-up
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);
		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, 0.4, -1), this);
		light.power = 2;
		attachUI(new Lobbydesign());
	}

	/** Attach the 2D domkit HUD (built by Lobbydesign) onto the 2D scene. */
	function attachUI(design : Lobbydesign)
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
