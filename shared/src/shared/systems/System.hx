package shared.systems;

import shared.IUpdate;
import shared.events.EventBus;

/**
	Base class for isolated systems (client + server).

	Contract: a system talks ONLY through the event bus (`bus.subscribe` /
	`bus.publish`) and its own internal state. It never holds references to
	other systems, views, or the sim — that keeps systems swappable and
	simulation order deterministic (the container runs them in insert order).

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

	public function new(bus : EventBus, ?name : String)
	{
		this.bus = bus;
		this.name = name != null ? name : Type.getClassName(Type.getClass(this));
		this.enabled = true;
	}

	function set_enabled(v : Bool) : Bool
	{
		return enabled = v;
	}

	/** Per-frame/tick update; override in concrete systems. */
	public function update(dt : Float) : Void {}
}
