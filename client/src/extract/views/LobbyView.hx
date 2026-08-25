package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import extract.design.Lobbydesign;

/**
	Root scene of the whole lobby. Extends the 3D scene so all 3D models
	are rendered here; the 2D HUD (Lobbydesign) is attached on top via the
	2D scene.
**/
class LobbyView extends Scene3D
{
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

	/** Attach the 2D HUD (built by Lobbydesign) onto the 2D scene. */
	public function attachUI(design : Lobbydesign, s2d : Scene2D)
	{
		s2d.addChild(design);
	}

	/** Add a 3D model into the lobby scene. */
	public function addModel(o : h3d.scene.Object)
	{
		this.addChild(o);
	}

	/** Per-frame update hook (kept for parity with HeapsApp.update). */
	public function update(dt : Float)
	{
	}
}
