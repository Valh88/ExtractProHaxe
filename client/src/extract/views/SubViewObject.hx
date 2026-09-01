package extract.views;

import h2d.Object;

/**
	Base class for switchable lobby sub-views.
	Each sub-view creates its own domkit design and assigns it to `design`;
	access the concrete type via `designAs()`.
**/
class SubViewObject extends Object implements ISubView
{
	/** The domkit design attached by LobbyView into the sub-view container. */
	public var design : Object;

	public function new(?parent : Object)
	{
		super(parent);
	}

	public function designAs<T : h2d.Object>(c : Class<T>) : T
	{
		return Std.downcast(design, c);
	}
}