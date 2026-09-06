package extract.systems;

import h3d.Camera;
import hxd.Key;

import extract.utils.CameraController;
import extract.utils.MovementController;
import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.systems.System;

/**
	Client-side player controller: composes the extensible CameraController
	(look) and MovementController (WASD) and publishes intents to the bus.
	Never touches the sim — the HeroSystem (shared) applies movement, which
	keeps client and server simulations identical.

	Input: RMB drag to look, WASD/Shift to move. Camera anchor is the hero
	mesh (interpolated by PhysRenderer); cdb numbers are read once per mesh
	bind.
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
	var rmbDown : Bool = false;
	var dragging : Bool = false;
	var mx : Float = 0;
	var my : Float = 0;
	var lastMX : Float = 0;
	var lastMY : Float = 0;
	// last published intent (publish only on change)
	var pDirX : Float = 0;
	var pDirZ : Float = 0;
	var pYaw : Float = 0;
	var pMag : Float = 0;

	public function new(bus : EventBus, cam : Camera, mesh : Null<h3d.scene.Object>, ?gd : GameData)
	{
		super(bus, null, gd, "PlayerController");
		this.cam = cam;
		this.camCtrl = new CameraController(cam);
		this.moveCtrl = new MovementController();
		this.mesh = mesh;
		hxd.Window.getInstance().addEventTarget(onEvent);
	}

	function set_mesh(m : Null<h3d.scene.Object>) : Null<h3d.scene.Object>
	{
		camCtrl.snap();
		// cache cdb-driven numbers once per bind (they don't change between respawns)
		var r = gd.f("Hero", "heroRadius", 0.4);
		var hh = gd.f("Hero", "heroHalfHeight", 0.45);
		camCtrl.eyeHeight = gd.f("Hero", "eyeHeight", 1.6) - (r + hh);
		camCtrl.sensitivity = gd.f("Camera", "sensitivity", 0.005);
		camCtrl.fov = gd.f("Camera", "fov", 75);
		// FPS: eye snaps to the anchor (mesh is already interpolated by
		// PhysRenderer) — no second smoothing pass, or the body visibly
		// outruns the camera and jitters
		camCtrl.followRate = 0;
		camCtrl.invertX = true; // mouse right -> camera left (request)
		moveCtrl.speed = gd.f("Hero", "speed", 6);
		moveCtrl.invertX = true; // A<->D swapped (request)
		moveCtrl.invertZ = false; // W/S normal (invertZ was the W-backward bug)
		return mesh = m;
	}

	function onEvent(e : hxd.Event) : Void
	{
		switch (e.kind)
		{
			case EMove:
				mx = e.relX;
				my = e.relY;
			case EPush if (e.button == 1):
				rmbDown = true;
				dragging = false;
				mx = e.relX;
				my = e.relY;
			case ERelease if (e.button == 1):
				rmbDown = false;
			case _:
		}
	}

	override public function update(dt : Float) : Void
	{
		// --- look ---
		if (rmbDown)
		{
			if (!dragging)
			{
				dragging = true;
				lastMX = mx;
				lastMY = my;
			}
			else
			{
				camCtrl.addLook(mx - lastMX, my - lastMY);
				lastMX = mx;
				lastMY = my;
			}
		}
		else
		{
			dragging = false;
			if (Key.isDown(Key.LEFT)) camCtrl.addLook(2, 0);   // keyboard fallback
			if (Key.isDown(Key.RIGHT)) camCtrl.addLook(-2, 0);
		}

		// --- move ---
		moveCtrl.setYaw(camCtrl.yaw);
		moveCtrl.update(dt);

		// --- publish intent on change ---
		var d = moveCtrl.dirWorld();
		var yaw = camCtrl.yaw;
		var mag = moveCtrl.magnitude();
		if (d.x != pDirX || d.z != pDirZ || yaw != pYaw || mag != pMag)
		{
			pDirX = d.x;
			pDirZ = d.z;
			pYaw = yaw;
			pMag = mag;
			bus.publish(new HeroMoveIntent(d.x, d.z, yaw, mag));
		}

		// --- camera follows the hero mesh anchor ---
		if (mesh == null) return;
		var p = mesh.getAbsPos();
		camCtrl.anchor.set(p.tx, p.ty, p.tz);
		camCtrl.update(dt);
	}
}
