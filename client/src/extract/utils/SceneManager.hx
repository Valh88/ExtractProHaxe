package extract.utils;

import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import h3d.scene.Scene as Scene3D;

import shared.IUpdate;

/** App scenes switchable via SceneManager. */
enum GameScene
{
	Lobby;
	Gameplay;
}

/**
	Scene switcher: holds a lazily created map of scenes and switches the
	active one on the app. Pump `update(dt)` from App.update.

	Generic over the scene key `K` (e.g. `GameScene`): scene construction is
	delegated to the `factory` passed to the constructor, so the manager knows
	nothing about concrete views or their dependencies (style/gd/bus) — the
	owner of the factory does.
**/
class SceneManager<K : EnumValue>
{
	var app : hxd.App;
	var factory : K -> Scene3D;
	var scenes : Map<K, Scene3D> = new Map();

	public var current(default, null) : Null<K>;
	public var currentScene(default, null) : Null<IUpdate>;

	public function new(app : hxd.App, factory : K -> Scene3D)
	{
		this.app = app;
		this.factory = factory;
	}

	public function switchScene(id : K) : Void
	{
		if (current == id) return;

		// dispose + drop the previously active scene so its owned resources
		// (network sockets held by presentation systems, tweens) are released
		if (current != null)
		{
			var prev = scenes.get(current);
			if (prev != null)
			{
				prev.dispose();
				scenes.remove(current);
			}
		}

		var scene = scenes.get(id);
		if (scene == null)
		{
			scene = factory(id);
			scenes.set(id, scene);
		}
		current = id;
		currentScene = cast scene;
		app.setScene(scene);
	}

	public function update(dt : Float) : Void
	{
		if (currentScene == null) return;
		currentScene.update(dt);
	}
}
