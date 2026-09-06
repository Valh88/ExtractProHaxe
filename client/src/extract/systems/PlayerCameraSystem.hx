package extract.systems;

import h3d.Camera;
import hxd.Key;

import extract.utils.CameraController;
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/**
	Presentation system driving the first-person camera via the extensible
	`CameraController`. The hero mesh is the anchor (interpolated by
	PhysRenderer each frame); the controller owns all tuning (eye height,
	sensitivity, fov, follow rate...).

	Input: RMB drag to look (same scheme as CameraFly). Movement input is a
	later step. Numbers come from cdb ("Hero" sheet) once per mesh bind.
**/
class PlayerCameraSystem extends System
{
	/** Hero mesh anchor (set by the view when the hero mesh is created). */
	public var mesh(default, set) : Null<h3d.scene.Object>;

	/** The extensible camera controller (tune its public fields freely). */
	public var ctrl(default, null) : CameraController;

	var cam : Camera;
	var rmbDown : Bool = false;
	var dragging : Bool = false;
	var mx : Float = 0;
	var my : Float = 0;
	var lastMX : Float = 0;
	var lastMY : Float = 0;

	public function new(bus : EventBus, cam : Camera, mesh : Null<h3d.scene.Object>, ?gd : GameData)
	{
		super(bus, null, gd, "PlayerCamera");
		this.cam = cam;
		this.ctrl = new CameraController(cam);
		this.mesh = mesh;
		hxd.Window.getInstance().addEventTarget(onEvent);
	}

	function set_mesh(m : Null<h3d.scene.Object>) : Null<h3d.scene.Object>
	{
		ctrl.snap();
		// cache cdb-driven numbers once per bind (they don't change between respawns)
		var r = gd.f("Hero", "heroRadius", 0.4);
		var hh = gd.f("Hero", "heroHalfHeight", 0.45);
		ctrl.eyeHeight = gd.f("Hero", "eyeHeight", 1.6) - (r + hh);
		ctrl.sensitivity = gd.f("Camera", "sensitivity", 0.005);
		ctrl.fov = gd.f("Camera", "fov", 75);
		ctrl.followRate = gd.f("Camera", "followRate", 18);
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
		// look input: RMB drag deltas feed the controller
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
				ctrl.addLook(mx - lastMX, my - lastMY);
				lastMX = mx;
				lastMY = my;
			}
		}
		else
		{
			dragging = false;
			if (Key.isDown(Key.LEFT)) ctrl.addLook(2, 0);      // keyboard fallback
			if (Key.isDown(Key.RIGHT)) ctrl.addLook(-2, 0);
		}

		if (mesh == null) return;
		var p = mesh.getAbsPos();
		ctrl.anchor.set(p.tx, p.ty, p.tz);
		ctrl.update(dt);
	}
}
