package extract;

import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import h3d.scene.Scene as Scene3D;

import shared.IUpdate;
import shared.events.EventBus;
import extract.views.GamePlayView;
import extract.views.LobbyView;

/** App scenes switchable via SceneManager. */
enum GameScene
{
	Lobby;
	Gameplay;
}

/**
	Scene switcher: holds a lazily created map of scenes and switches the
	active one on the app. Pump `update(dt)` from App.update.
**/
class SceneManager
{
	var app : hxd.App;
	var s2d : Scene2D;
	var style : Style;
	var bus : EventBus;
	var scenes : Map<GameScene, Scene3D> = new Map();

	public var current(default, null) : Null<GameScene>;
	public var currentScene(default, null) : Null<IUpdate>;

	public function new(app : hxd.App, s2d : Scene2D, style : Style, bus : EventBus)
	{
		this.app = app;
		this.s2d = s2d;
		this.style = style;
		this.bus = bus;
	}

	public function switchScene(id : GameScene) : Void
	{
		if (current == id) return;
		var scene = scenes.get(id);
		if (scene == null)
		{
			scene = createScene(id);
			if (scene == null) return;
			scenes.set(id, scene);
		}
		current = id;
		currentScene = cast scene;
		app.setScene(scene);
	}

	function createScene(id : GameScene) : Scene3D
	{
		return switch (id)
		{
			case Lobby: new LobbyView(s2d, style, bus);
			case Gameplay: new GamePlayView(s2d, style);
		}
	}

	public function update(dt : Float) : Void
	{
		if (currentScene == null) return;
		currentScene.update(dt);
	}
}