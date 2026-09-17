package extract.systems;

import h3d.Camera;
import hxd.Key;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import extract.models.HeroVisual;
import extract.utils.CameraController;
import extract.utils.MovementController;
import extract.utils.animations.AnimationController;
import extract.utils.animations.SineAnimation;
import shared.GameData;
import shared.Player;
import shared.SimWorld;
import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.AimStateChanged;
import shared.systems.System;

/**
	Client-side player controller: composes the extensible CameraController
	(look) and MovementController (WASD) and publishes intents to the bus.

	Look follows the mouse continuously (cursor hidden in-game); LMB fires;
	RMB hold blends into ADS (aim-down-sights) — weapon lerp + FOV zoom.
	Camera anchor is the hero mesh (interpolated by PhysRenderer); cdb numbers
	are read once per mesh bind.

	When the settings menu is open (`GameplayState.fsSettings`), movement /
	look / shoot are frozen AND the hero body's velocity is zeroed directly
	via `SimWorld` (bypassing the bus to avoid the one-frame delivery delay).
**/
class PlayerControllerSystem extends System
{
	/** Hero visuals (set by the view when the hero body spawns). */
	public var hero(default, set) : Null<HeroVisual>;

	/** Extensible camera controller (eye height, sensitivity, fov, ...). */
	public var camCtrl(default, null) : CameraController;

	/** Keyboard movement controller (speed, inertia). */
	public var moveCtrl(default, null) : MovementController;

	var cam : Camera;
	var shootRequested : Bool = false;
	/** Bullet spawn clearance along the fire direction (cached from cdb). */
	var spawnAhead : Float = 0.6;
	// last published intent (publish only on change)
	var pDirX : Float = 0;
	var pDirZ : Float = 0;
	var pYaw : Float = 0;
	var pMag : Float = 0;

	// --- ADS (aim-down-sights) ---
	/** Blend factor 0=hip 1=ADS, interpolated each frame. */
	public var adsBlend(default, null) : Float = 0;
	/** FOV at hip (cached from cdb on bind). */
	var defaultFov : Float = 75;
	/** FOV when fully aimed (from cdb Camera.adsFov). */
	var adsFov : Float = 60;
	/** Transition speed in seconds (from cdb Camera.adsSpeed). */
	var adsSpeed : Float = 0.15;
	/** Mouse sensitivity multiplier when fully aimed (from cdb Camera.adsSensMult). */
	var adsSensMult : Float = 0.5;
	/** Original sensitivity at hip (cached on bind). */
	var defaultSensitivity : Float = 0.005;
	/** Tracks last published aim state to publish AimStateChanged only on flip. */
	var lastAiming : Bool = false;

	// --- weapon anchor smoothing ---
	/** Weapon rotation follows camera with independent exponential smoothing,
	    creating a subtle lag effect (weapon "catches up" when turning).
	    Position snaps to eye instantly — no position lag avoids jerk during movement. */
	var weaponSmooth : Float = 15;
	/** Smoothed weapon anchor rotation. */
	var sWpnPitch : Float = 0;
	var sWpnYaw : Float = 0;
	/** True until the first sync (snap instead of smooth). */
	var wpnHasState : Bool = false;

	// --- idle sway (SineAnimation instances managed by wpnAnim) ---
	var wpnAnim : AnimationController;
	var swayOsc : SineAnimation;
	var breathOsc : SineAnimation;
	var rollOsc : SineAnimation;
	var bobOsc : SineAnimation;
	/** Extra sway multiplier while moving (0 = no extra). */
	var wpnMoveSwayMult : Float = 1.5;

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

	public function new(bus : EventBus, sim : SimWorld, cam : Camera, ?hero : HeroVisual, ?gd : GameData)
	{
		super(bus, sim, gd, "PlayerController");
		this.cam = cam;
		this.camCtrl = new CameraController(cam);
		this.moveCtrl = new MovementController();
		this.hero = hero;
		winHandler = onWindowEvent;
		hxd.Window.getInstance().addEventTarget(winHandler);

		// idle sway oscillators (continuous, managed by local AnimationController)
		wpnAnim = new AnimationController();
		swayOsc = new SineAnimation(0.003, 1.5);
		breathOsc = new SineAnimation(0.002, 1.2);
		rollOsc = new SineAnimation(0.004, 1.0);
		bobOsc = new SineAnimation(0.004, 8.0);
		wpnAnim.add(swayOsc);
		wpnAnim.add(breathOsc);
		wpnAnim.add(rollOsc);
		wpnAnim.add(bobOsc);
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

	function set_hero(h : Null<HeroVisual>) : Null<HeroVisual>
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
		defaultFov = camCtrl.fov;
		adsFov = gd.req("Camera", "adsFov");
		adsSpeed = gd.req("Camera", "adsSpeed");
		adsSensMult = gd.req("Camera", "adsSensMult");
		defaultSensitivity = camCtrl.sensitivity;
		weaponSmooth = gd.req("Camera", "weaponSmooth");
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
		return hero = h;
	}

	override public function update(dt : Float) : Void
	{
		if (inSettings)
		{
			// settings open — freeze look, consume delta, snap ADS back to hip
			accDX = 0;
			accDY = 0;
			adsBlend = 0;
			if (hero != null)
			{
				var p = hero.bodyMesh.getAbsPos();
				camCtrl.anchor.set(p.tx, p.ty, p.tz);
				camCtrl.update(dt);
				syncWeaponAnchor(dt);
			}
			return;
		}

		// --- ADS (right mouse button hold) ---
		var isAiming = Key.isDown(Key.MOUSE_RIGHT);
		var adsTarget : Float = isAiming ? 1.0 : 0.0;
		var adsDelta = adsTarget - adsBlend;
		if (adsDelta != 0)
		{
			var k = adsSpeed > 0 ? dt / adsSpeed : 1.0;
			if (k > 1) k = 1;
			adsBlend += adsDelta * k;
		}
		if (isAiming != lastAiming)
		{
			lastAiming = isAiming;
			bus.publish(new AimStateChanged(isAiming));
		}

		// sensitivity scales down with ADS blend
		camCtrl.sensitivity = defaultSensitivity * (1.0 - adsBlend * (1.0 - adsSensMult));

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

		// --- shoot (LMB one-shot): fire from the eye along the view dir,
		// starting beyond the hero capsule so it doesn't hit the player ---
		if (Key.isPressed(Key.MOUSE_LEFT)) shootRequested = true;
		if (shootRequested)
		{
			shootRequested = false;
			if (hero != null)
			{
				var p = hero.bodyMesh.getAbsPos();
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
		if (hero == null) return;
		var p = hero.bodyMesh.getAbsPos();
		camCtrl.anchor.set(p.tx, p.ty, p.tz);
		camCtrl.update(dt);
		wpnAnim.update(dt);
		syncWeaponAnchor(dt);
	}

	/** Sync the weapon anchor (cameraAnchor inside HeroVisual) to the camera.
		Position snaps to eye (no lag — avoids movement jerk).
		Rotation uses independent exponential smoothing (weapon "catches up"
		when turning, giving a sense of weight).
		Idle sway comes from SineAnimation oscillators managed by wpnAnim. */
	function syncWeaponAnchor(dt : Float) : Void
	{
		var kw = weaponSmooth > 0 ? 1 - Math.exp(-weaponSmooth * dt) : 1;

		var ca = hero.cameraAnchor;
		ca.x = camCtrl.eye.x;
		ca.y = camCtrl.eye.y;
		ca.z = camCtrl.eye.z;

		if (!wpnHasState)
		{
			sWpnPitch = camCtrl.pitch;
			sWpnYaw = camCtrl.yaw;
			wpnHasState = true;
		}
		else
		{
			sWpnPitch += (camCtrl.pitch - sWpnPitch) * kw;
			sWpnYaw += (camCtrl.yaw - sWpnYaw) * kw;
		}
		ca.setRotation(sWpnPitch, sWpnYaw, 0);

		// --- idle sway from SineAnimation oscillators ---
		var idle = 1.0 - adsBlend;
		var moving = moveCtrl.magnitude();
		var moveBoost = 1.0 + moving * wpnMoveSwayMult;

		var sx = swayOsc.value * idle * moveBoost;
		var sy = breathOsc.value * idle * moveBoost;
		var sr = rollOsc.value * idle * moveBoost;
		var bob = bobOsc.value * moving * idle;

		// apply sway on top of base weapon transform
		var w = hero.mainWeapon;
		var b = adsBlend;
		w.x = HeroVisual.HIP_X + (HeroVisual.ADS_X - HeroVisual.HIP_X) * b + sx;
		w.y = HeroVisual.HIP_Y + (HeroVisual.ADS_Y - HeroVisual.HIP_Y) * b + sy + bob;
		w.z = HeroVisual.HIP_Z + (HeroVisual.ADS_Z - HeroVisual.HIP_Z) * b;
		w.setScale(HeroVisual.HIP_SCALE + (HeroVisual.ADS_SCALE - HeroVisual.HIP_SCALE) * b);
		w.setRotation(-Math.PI / 2 + sr, -Math.PI / 2, 0);

		// lerp FOV between hip and ADS
		camCtrl.fov = defaultFov + (adsFov - defaultFov) * b;
	}

	override public function dispose() : Void
	{
		hxd.Window.getInstance().removeEventTarget(winHandler);
	}
}