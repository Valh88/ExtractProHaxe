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
	Client-side player controller: composes the extensible CameraController
	(look) and MovementController (WASD) and publishes intents to the bus.

	Look follows the mouse continuously (cursor hidden in-game); LMB fires.
	Camera anchor is the hero mesh (interpolated by PhysRenderer); cdb numbers
	are read once per mesh bind.

	When the settings menu is open (`GameplayState.fsSettings`), movement /
	look / shoot are frozen AND the hero body's velocity is zeroed directly
	via `SimWorld` (bypassing the bus to avoid the one-frame delivery delay).
**/
class PlayerControllerSystem extends System
{
	/** Hero mesh anchor (set by the view when the hero mesh is created). */
	public var mesh(default, set) : Null<h3d.scene.Object>;

	/** Extensible camera controller (eye height, sensitivity, fov, ...). */
	public var camCtrl(default, null) : CameraController;

	/** Keyboard movement controller (speed, inertia). */
	public var moveCtrl(default, null) : MovementController;

	var cam : Camera;
	var sim : SimWorld;
	var shootRequested : Bool = false;
	/** Bullet spawn clearance along the fire direction (cached from cdb). */
	var spawnAhead : Float = 0.6;
	// last published intent (publish only on change)
	var pDirX : Float = 0;
	var pDirZ : Float = 0;
	var pYaw : Float = 0;
	var pMag : Float = 0;

	/** True while the settings menu is open — freeze everything. */
	var inSettings(get, never) : Bool;

	function get_inSettings() : Bool
		return GameplayState.get().current == GameplayMode.fsSettings;

	/** Was in settings last frame — used to skip the first delta after closing. */
	var wasInSettings : Bool = false;

	// mouse delta tracking (single Window listener for the whole project)
	final winHandler : hxd.Event -> Void;
	var lastX : Float = 0;
	var lastY : Float = 0;
	var gotBaseline : Bool = false;
	var accDX : Float = 0;
	var accDY : Float = 0;

	public function new(bus : EventBus, sim : SimWorld, cam : Camera, mesh : Null<h3d.scene.Object>, ?gd : GameData)
	{
		super(bus, null, gd, "PlayerController");
		this.sim = sim;
		this.cam = cam;
		this.camCtrl = new CameraController(cam);
		this.moveCtrl = new MovementController();
		this.mesh = mesh;
		winHandler = onWindowEvent;
		hxd.Window.getInstance().addEventTarget(winHandler);
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

	function set_mesh(m : Null<h3d.scene.Object>) : Null<h3d.scene.Object>
	{
		camCtrl.snap();
		// cdb-driven tuning, read once per bind (they don't change between
		// respawns); ALL data lives in the base — required reads, a missing
		// field throws a clear error at startup
		var r = gd.req("Hero", "heroRadius");
		var hh = gd.req("Hero", "heroHalfHeight");
		camCtrl.eyeHeight = gd.req("Camera", "eyeHeight") - (r + hh);
		camCtrl.sensitivity = gd.req("Camera", "sensitivity");
		camCtrl.fov = gd.req("Camera", "fov");
		camCtrl.maxPitch = gd.req("Camera", "maxPitch");
		camCtrl.lookSmooth = gd.req("Camera", "lookSmooth");
		camCtrl.invertX = gd.reqB("Camera", "invertX");
		camCtrl.invertY = gd.reqB("Camera", "invertY");
		// FPS: eye snaps to the anchor (mesh is already interpolated by
		// PhysRenderer) — a very high follow rate filters the 30 Hz
		// contact/gravity micro-wobble without perceptible lag
		camCtrl.followRate = 0;
		moveCtrl.speed = gd.req("Hero", "speed");
		moveCtrl.moveSmooth = gd.req("Controller", "moveSmooth");
		moveCtrl.stopSmooth = gd.req("Controller", "stopSmooth");
		moveCtrl.stopThreshold = gd.req("Controller", "stopThreshold");
		moveCtrl.fastMult = gd.req("Controller", "fastMult");
		moveCtrl.invertX = gd.reqB("Controller", "invertX");
		moveCtrl.invertZ = gd.reqB("Controller", "invertZ");
		// bullet spawn clearance: eye is inside the hero capsule, so the
		// projectile must start beyond it along the fire direction
		spawnAhead = gd.req("Hero", "heroRadius") + gd.req("Bullet", "radius") + 0.05;
		return mesh = m;
	}

	override public function update(dt : Float) : Void
	{
		if (inSettings)
		{
			// settings open — freeze look + consume accumulated delta
			accDX = 0;
			accDY = 0;
			wasInSettings = true;
			return;
		}

		// first frame after closing settings — discard stale delta, skip look
		if (wasInSettings)
		{
			wasInSettings = false;
			accDX = 0;
			accDY = 0;
		}
		else
		{
			// --- look (mouse delta from the window handler) ---
			camCtrl.addLook(accDX, accDY);
		}
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

		// --- shoot (LMB one-shot): fire from the eye along the view dir,
		// starting beyond the hero capsule so it doesn't hit the player ---
		if (Key.isPressed(Key.MOUSE_LEFT)) shootRequested = true;
		if (shootRequested)
		{
			shootRequested = false;
			if (mesh != null)
			{
				var p = mesh.getAbsPos();
				var eyeY = p.ty + camCtrl.eyeHeight;
				var cp = Math.cos(camCtrl.pitch);
				var fx = -Math.sin(camCtrl.yaw) * cp;
				var fy = Math.sin(camCtrl.pitch);
				var fz = -Math.cos(camCtrl.yaw) * cp;
				bus.publish(new BulletFired(Player.LOCAL,
					p.tx + fx * spawnAhead,
					eyeY + fy * spawnAhead,
					p.tz + fz * spawnAhead,
					fx, fy, fz));
			}
		}

		// --- camera follows the hero mesh anchor ---
		if (mesh == null) return;
		var p = mesh.getAbsPos();
		camCtrl.anchor.set(p.tx, p.ty, p.tz);
		camCtrl.update(dt);
	}

	override public function dispose() : Void
	{
		hxd.Window.getInstance().removeEventTarget(winHandler);
	}
}