package extract;

import h3d.Vector;
import hxd.App;
import extract.events.ClientEventBus;
import extract.utils.SceneManager;
import extract.utils.SceneManager.GameScene;
import extract.views.LobbyView;
import extract.views.GamePlayView;

class HeapsApp extends App
{
	var sceneManager : SceneManager<GameScene>;
	var eventBus : ClientEventBus;

	/** Global domkit style shared by all views (loads ui/lobby.css once). */
	public var uiStyle : h2d.domkit.Style;

	override function init()
	{
		// app-wide UI style: first thing so every view can style.addObject()
		uiStyle = new h2d.domkit.Style();
		uiStyle.load(hxd.Res.load("ui/lobby.css"));

		// starter data-config from the shared cdb (raw db access, see GameData)
		var gd = shared.GameData.fromCdb(hxd.Res.load("db/data.cdb").toText());
		trace("GAMEDATA db=" + (gd.db != null ? "loaded" : "null"));

		// shared event bus (local delivery on flush, transport in subclass)
		eventBus = new ClientEventBus();

		// scene manager handles creation/caching/switching of scenes;
		// the factory closes over style/gd/bus — the app owns dependencies
		sceneManager = new SceneManager<GameScene>(this, function(id : GameScene)
		{
			return switch (id)
			{
				case Lobby: new LobbyView(s2d, uiStyle, gd, eventBus);
				case Gameplay: new GamePlayView(s2d, uiStyle, gd);
			}
		});
		sceneManager.switchScene(GameScene.Lobby);
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