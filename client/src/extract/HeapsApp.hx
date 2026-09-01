package extract;

import h3d.Vector;
import hxd.App;

class HeapsApp extends App
{
	var sceneManager : SceneManager;

	/** Global domkit style shared by all views (loads ui/lobby.css once). */
	public var uiStyle : h2d.domkit.Style;

	override function init()
	{
		// app-wide UI style: first thing so every view can style.addObject()
		uiStyle = new h2d.domkit.Style();
		uiStyle.load(hxd.Res.load("ui/lobby.css"));

		// scene manager handles creation/caching/switching of scenes
		sceneManager = new SceneManager(this, s2d, uiStyle);
		sceneManager.switchScene(SceneManager.GameScene.Gameplay);
	}

	override function update(dt : Float)
	{
		super.update(dt);
		sceneManager.update(dt);
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