package extract;

import h3d.Vector;
import hxd.App;
import extract.events.ClientEventBus;

class HeapsApp extends App
{
	var sceneManager : SceneManager;
	var eventBus : ClientEventBus;

	/** Global domkit style shared by all views (loads ui/lobby.css once). */
	public var uiStyle : h2d.domkit.Style;

	override function init()
	{
		// app-wide UI style: first thing so every view can style.addObject()
		uiStyle = new h2d.domkit.Style();
		uiStyle.load(hxd.Res.load("ui/lobby.css"));

		// shared event bus (local delivery on flush, transport in subclass)
		eventBus = new ClientEventBus();

		// scene manager handles creation/caching/switching of scenes
		sceneManager = new SceneManager(this, s2d, uiStyle, eventBus);
		sceneManager.switchScene(SceneManager.GameScene.Lobby);
	}

	override function update(dt : Float)
	{
		super.update(dt);
		sceneManager.update(dt);
		eventBus.flush(); // dispatch queued events at end of frame
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