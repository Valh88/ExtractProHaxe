package serv.systems;

import shared.systems.System;
import shared.events.EventBus;

/**
	Demo room-only system: logs a heartbeat once per second of room ticks.
	Attached to `roomSystems` (NOT the sim) — it is server-only logic, never
	mirrored to a client, and runs after the world's sim systems each tick.
**/
class DemoLogSystem extends System
{
	var acc : Float = 0;

	public function new(bus : EventBus)
	{
		super(bus, null, null, "DemoLog");
	}

	override public function update(dt : Float) : Void
	{
		acc += dt;
		if (acc >= 1.0)
		{
			acc -= 1.0;
			trace("DemoRoom heartbeat");
		}
	}
}