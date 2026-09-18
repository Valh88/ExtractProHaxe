package extract.utils;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import shared.GameData;
import shared.IUpdate;
import shared.events.EventBus;
import shared.systems.Systems;
import extract.utils.animations.AnimationController;

/** Common root-scene scaffolding: 2D/domkit handles, game data, camera, theme light. */
class BaseScene extends Scene3D implements IUpdate
{
	public var s2d(default, null) : Scene2D;
	public var style(default, null) : Style;
	/** Shared game numbers (cdb-overridable), available to every scene. */
	public var gd(default, null) : GameData;
	/** Client-side event bus (same instance as the app's). */
	public var bus(default, null) : EventBus;
	/** Presentation/input systems — advanced at the start of update(). */
	public var systems(default, null) : Systems;
	/** Scene-local animation controller — each scene owns its own tweens. */
	public var animCtrl(default, null) : AnimationController;
	/** The base theme light created by createLight() — scenes may disable it
		(remove()) to install their own sun/lighting (see GamePlayView). */
	public var themeLight(default, null) : h3d.scene.pbr.DirLight;

	public function new(s2d : Scene2D, style : Style, gd : GameData, ?bus : EventBus, ?bgColor : Null<Int>)
	{
		super();
		this.s2d = s2d;
		this.style = style;
		this.gd = gd;
		this.bus = bus != null ? bus : new EventBus();
		this.systems = new Systems();
		this.animCtrl = new AnimationController();
		if (bgColor != null)
			h3d.Engine.getCurrent().backgroundColor = bgColor;
		setupCamera();
		createLight();
	}

	function setupCamera() : Void
	{
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);
	}

	function createLight() : h3d.scene.pbr.DirLight
	{
		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, -0.4, -1), this);
		light.power = 2;
		light.isMainLight = true;
		light.shadows.mode = h3d.pass.Shadows.RenderMode.Dynamic;
		light.shadows.size = 3048;
		light.shadows.power = 150;
		light.shadows.bias *= 0.3;
		themeLight = light;
		return light;
	}

	public function update(dt : Float) : Void
	{
		systems.update(dt); // presentation/input systems first...
		style.sync(dt);     // domkit applies CSS properties
		animCtrl.update(dt); // then animation overrides (alpha, y, etc.)
	}

	/**
		Release scene-owned resources (systems hold sockets/subscriptions and
		release them via System.dispose()). Called by the SceneManager when the
		scene is switched away.
	**/
	override public function dispose() : Void
	{
		systems.clear();
		animCtrl.clear();
		super.dispose();
	}
}