package extract.systems;

import h3d.Camera;
import hxd.Key;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import extract.utils.CameraController;
import extract.utils.MovementController;
import shared.GameData;
import shared.Player;
import shared.SimWorld;
import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.BulletFired;
import shared.systems.System;

/**
	Client-side player controller: composes CameraController (look) and
	MovementController (WASD), publishes intents to the bus, handles shooting.

	All hero visual logic (ADS, weapon sync, sway, camera anchor, FOV)
	lives in `heroVisCtrl : HeroVisualController`.
**/
class PlayerControllerSystem extends System
{
	/** Hero visual controller (self-binds on LocalHeroSpawned bus event). */
	public var heroVisCtrl(default, null) : HeroVisualController;

	/** Extensible camera controller (eye height, sensitivity, fov, ...). */
	public var camCtrl(default, null) : CameraController;

	/** Keyboard movement controller (speed, inertia). */
	public var moveCtrl(default, null) : MovementController;

	var cam : Camera;
	var shootRequested : Bool = false;

	// last published intent (publish only on change)
	var pDirX : Float = 0;
	var pDirZ : Float = 0;
	var pYaw : Float = 0;
	var pMag : Float = 0;

	/** True while the settings menu is open — freeze everything. */
	var inSettings(get, never) : Bool;

	function get_inSettings() : Bool
		return GameplayState.get().current == GameplayMode.fsSettings;

	// mouse delta tracking (single Window listener for the whole project)
	final winHandler : hxd.Event -> Void;
	var lastX : Float = 0;
	var lastY : Float = 0;
	var gotBaseline : Bool = false;
	var accDX : Float = 0;
	var accDY : Float = 0;

	public function new(bus : EventBus, sim : SimWorld, cam : Camera, ?gd : GameData)
	{
		super(bus, sim, gd, "PlayerController");
		this.cam = cam;
		this.camCtrl = new CameraController(cam);
		this.moveCtrl = new MovementController();
		this.heroVisCtrl = new HeroVisualController(bus, gd);
		winHandler = onWindowEvent;
		hxd.Window.getInstance().addEventTarget(winHandler);

		// read once: camera + movement params
		camCtrl.eyeHeight = gd.req("Camera", "eyeHeight") - (gd.req("Hero", "heroRadius") + gd.req("Hero", "heroHalfHeight"));
		camCtrl.sensitivity = gd.req("Camera", "sensitivity");
		camCtrl.fov = gd.req("Camera", "fov");
		camCtrl.maxPitch = gd.req("Camera", "maxPitch");
		camCtrl.lookSmooth = gd.req("Camera", "lookSmooth");
		camCtrl.invertX = gd.reqB("Camera", "invertX");
		camCtrl.invertY = gd.reqB("Camera", "invertY");
		camCtrl.followRate = 0;
		moveCtrl.speed = gd.req("Hero", "speed");
		moveCtrl.moveSmooth = gd.req("Controller", "moveSmooth");
		moveCtrl.stopSmooth = gd.req("Controller", "stopSmooth");
		moveCtrl.stopThreshold = gd.req("Controller", "stopThreshold");
		moveCtrl.fastMult = gd.req("Controller", "fastMult");
		moveCtrl.invertX = gd.reqB("Controller", "invertX");
		moveCtrl.invertZ = gd.reqB("Controller", "invertZ");
	}

	function onWindowEvent(e : hxd.Event) : Void
	{
		switch (e.kind)
		{
			case EMove:
				if (gotBaseline)
				{
					accDX += e.relX - lastX;
					accDY += e.relY - lastY;
				}
				lastX = e.relX;
				lastY = e.relY;
				gotBaseline = true;
			case _:
		}
	}

	/** Freeze the hero body + clear movement intent. Call BEFORE `sim.update()`
		so `HeroSystem.apply()` sees the cleared state in the same frame. */
	public function freezeHero() : Void
	{
		var body = sim.heroes.get(Player.LOCAL);
		if (body != null) body.setLinearVelocity(0, body.body.getLinearVelocity().y, 0);
		var heroSys : shared.systems.HeroSystem = cast sim.systems.get("Hero");
		if (heroSys != null) heroSys.clearIntent(Player.LOCAL);
	}

	override public function update(dt : Float) : Void
	{
		if (inSettings)
		{
			accDX = 0;
			accDY = 0;
			heroVisCtrl.snapToHip(camCtrl);
			if (heroVisCtrl.hero != null)
			{
				var p = heroVisCtrl.hero.bodyMesh.getAbsPos();
				camCtrl.anchor.set(p.tx, p.ty, p.tz);
			}
			camCtrl.update(dt);
			return;
		}

		// sensitivity scales with ADS blend
		camCtrl.sensitivity = heroVisCtrl.getSensitivity();

		// --- look (mouse delta from the window handler) ---
		camCtrl.addLook(accDX, accDY);
		accDX = 0;
		accDY = 0;

		// --- move ---
		moveCtrl.setYaw(camCtrl.yaw);
		moveCtrl.update(dt);

		// --- publish intent on change (jump is always delivered, one-shot) ---
		var d = moveCtrl.dirWorld();
		var yaw = camCtrl.yaw;
		var mag = moveCtrl.magnitude();
		var jump = moveCtrl.consumeJump();
		if (jump || d.x != pDirX || d.z != pDirZ || yaw != pYaw || mag != pMag)
		{
			pDirX = d.x;
			pDirZ = d.z;
			pYaw = yaw;
			pMag = mag;
			bus.publish(new HeroMoveIntent(Player.LOCAL, d.x, d.z, yaw, mag, jump));
		}

		// --- shoot (LMB one-shot) ---
		if (Key.isPressed(Key.MOUSE_LEFT)) shootRequested = true;
		if (shootRequested)
		{
			shootRequested = false;
			if (heroVisCtrl.hero != null)
			{
				var p = heroVisCtrl.hero.bodyMesh.getAbsPos();
				var eyeY = p.ty + camCtrl.eyeHeight;
				var cp = Math.cos(camCtrl.pitch);
				var fx = -Math.sin(camCtrl.yaw) * cp;
				var fy = Math.sin(camCtrl.pitch);
				var fz = -Math.cos(camCtrl.yaw) * cp;
				var sa = heroVisCtrl.spawnAhead;
				bus.publish(new BulletFired(Player.LOCAL,
					p.tx + fx * sa,
					eyeY + fy * sa,
					p.tz + fz * sa,
					fx, fy, fz));
			}
		}

		// --- camera + hero visuals ---
		if (heroVisCtrl.hero != null)
		{
			var p = heroVisCtrl.hero.bodyMesh.getAbsPos();
			camCtrl.anchor.set(p.tx, p.ty, p.tz);
		}
		camCtrl.update(dt);
		heroVisCtrl.update(dt, camCtrl, moveCtrl);
	}

	override public function dispose() : Void
	{
		hxd.Window.getInstance().removeEventTarget(winHandler);
	}
}
