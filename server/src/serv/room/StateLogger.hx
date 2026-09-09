package serv.room;

import phys.core.IPhysicsConsumer;
import phys.core.PhysBody;
import phys.core.PhysJoint;

/**
	World physics logger for a server room. Attached by the room itself to its
	world (`world.phys.addConsumer`) and driven by the room: the room calls
	`dump(dt)` once per tick, and this traces every body's last known position
	about once per second (throttled by accumulated `dt`, not call count).

	Pure server-side observation of the world — same consumer interface the
	client's renderer uses, but headless.
**/
class StateLogger implements IPhysicsConsumer
{
	/** How often to trace the body state (seconds). */
	public var interval : Float = 1.0;

	var last : Map<String, String>;
	var acc : Float = 0;

	public function new()
	{
		last = new Map();
	}

	public function onBodyAdded(b : PhysBody) : Void {}

	public function onBodyUpdated(b : PhysBody) : Void
	{
		var p = b.getPosition();
		last.set(b.name, fmt(p.x) + "," + fmt(p.y) + "," + fmt(p.z));
	}

	public function onBodyRemoved(b : PhysBody) : Void
	{
		last.remove(b.name);
	}

	public function onJointBroken(j : PhysJoint) : Void
	{
		trace("JOINT BROKEN " + j);
	}

	public function onPhysicsUpdate() : Void {}

	/** Called by the room each tick; traces body state about once per second. */
	public function dump(dt : Float) : Void
	{
		acc += dt;
		if (acc < interval) return;
		acc -= interval;
		for (k in last.keys())
			trace(k + " -> " + last.get(k));
	}

	public static function fmt(v : Float) : String
	{
		return (Math.round(v * 100) / 100) + "";
	}
}