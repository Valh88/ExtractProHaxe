package extract.utils;

import h2d.Object;
import h2d.Flow;
import shared.IUpdate;
import shared.events.EventBus;

/**
	Base class for switchable sub-views, generic over the concrete domkit
	design type `T` (e.g. `SubView<PlayDesign>`): `design` is exposed fully
	typed, no downcasts in subclasses.
	Each sub-view passes its design to the base ctor; the event bus flows
	through it as well.
**/
class SubView<T : Flow> extends Object implements IUpdate
{
	/** The domkit design attached by the parent view into its container. */
	public var design(default, null) : T;

	/** Shared event bus (client/server). */
	public var bus(default, null) : EventBus;

	public function new(bus : EventBus, design : T, ?parent : Object)
	{
		super(parent);
		this.bus = bus;
		this.design = design;
	}

	/** Per-frame update; override in sub-views. */
	public function update(dt : Float) : Void {}
}
