package extract.systems;

import phys.utils.CameraFly;

import shared.events.EventBus;
import shared.systems.System;

/**
	Presentation system wrapping the HeapsPhysics fly camera (debug view).
	Lives in BaseScene.systems (sim == null): it only moves the h3d camera,
	never touches the simulation.

	Toggle from code via `enabled` (no hotkey by design).
**/
class DebugCameraSystem extends System
{
	/** The underlying fly controller (WASD/QE/Shift move, RMB look). */
	public var fly(default, null) : CameraFly;

	public function new(bus : EventBus, cam : h3d.Camera, ?speed : Float)
	{
		super(bus);
		fly = new CameraFly(cam, speed);
	}

	override public function update(dt : Float) : Void
	{
		fly.update(dt);
	}
}
