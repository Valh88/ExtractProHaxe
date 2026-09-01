package extract;

import h3d.Vector;
import hxd.App;

import phys.core.PhysBody;
import phys.core.PhysCore;
import phys.render.PhysRenderer;

import shared.SimWorld;
import extract.views.GamePlayView;

class HeapsApp extends App
{

	var gamePlayView : GamePlayView;

	/** Global domkit style shared by all views (loads ui/lobby.css once). */
	public var uiStyle : h2d.domkit.Style;

	override function init()
	{
		// app-wide UI style: first thing so every view can style.addObject()
		uiStyle = new h2d.domkit.Style();
		uiStyle.load(hxd.Res.load("ui/lobby.css"));

		// gameplay scene (falling cubes) + HUD
		gamePlayView = new GamePlayView(s2d, uiStyle);
		setScene(gamePlayView);
	}

	override function update(dt : Float)
	{
		super.update(dt);

		gamePlayView.update(dt); // simulation + domkit style sync
	}

	override function loadAssets(done) 
	{
        #if sys
            hxd.Res.initLocal();
            done();
        #else
            new hxd.fmt.pak.Loader(s2d, done);
        #end
	}

	public static function app()
	{
		// PBR renderer (requires HashLink or WebGL 2.0)
		h3d.mat.MaterialSetup.current = new h3d.mat.PbrMaterialSetup();
		new HeapsApp();
	}
}
