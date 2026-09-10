package shared.systems;

import shared.IUpdate;
import shared.SimWorld;
import shared.GameData;
import shared.events.EventBus;

/**
	Base class for isolated systems (client + server).

	Contract: a system talks through the event bus (`bus.subscribe` /
	`bus.publish`), queries game data via `gd` (cdb) and its own internal
	state. It never holds references to OTHER systems or views. Systems
	attached to the simulation (`sim != null`) may read/mutate the world
	directly (`sim.heroes`, `sim.phys`) — they run inside SimWorld.update()
	in fixed order, so determinism is preserved. Client-side presentation
	systems (`sim == null`, e.g. BaseScene.systems) communicate only through
	events and never touch the sim.

	Heaps-free: safe to link on the headless server.
**/
class System implements IUpdate
{
	/** Human-readable id (used by Systems.get/remove). */
	public var name(default, null) : String;

	/** Disabled systems are skipped by the container's update. */
	public var enabled(default, set) : Bool;

	/** The only communication channel — client bus or server bus. */
	public var bus(default, null) : EventBus;

	/** Game database handle — query tunables directly: gd.f("Hero", "speed", 6). */
	public var gd(default, null) : GameData;

	/** The simulation world (null for client-side presentation systems). */
	public var sim(default, null) : Null<SimWorld>;

	public function new(bus : EventBus, ?sim : SimWorld, ?gd : GameData, ?name : String)
	{
		this.bus = bus;
		this.sim = sim;
		this.gd = gd != null ? gd : new GameData();
		this.name = name != null ? name : Type.getClassName(Type.getClass(this));
		this.enabled = true;
	}

	function set_enabled(v : Bool) : Bool
	{
		return enabled = v;
	}

	/** Per-frame/tick update; override in concrete systems. */
	public function update(dt : Float) : Void {}

	/**
		Release owned resources (sockets, subscriptions, timers). Called by the
		container on remove()/clear(). Empty by default — override in systems
		that hold external resources.
	**/
	public function dispose() : Void {}
}
