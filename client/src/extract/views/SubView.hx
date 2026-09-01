package extract.views;

import h2d.Object;
import h2d.Flow;
import shared.IUpdate;
import shared.events.EventBus;

/**
	Base class for switchable lobby sub-views.
	Each sub-view creates its own domkit Flow design and assigns it to `design`.
	The event bus is passed through the base ctor.
**/
class SubView extends Object implements IUpdate
{
	/** The domkit design attached by LobbyView into the sub-view container. */
	public var design : Flow;

	/** Shared event bus (client/server). */
	public var bus(default, null) : EventBus;

	public function new(bus : EventBus, ?parent : Object)
	{
		super(parent);
		this.bus = bus;
	}

	/** Per-frame update; override in sub-views. */
	public function update(dt : Float) : Void {}
}