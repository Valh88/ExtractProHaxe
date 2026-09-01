package extract.views;

import h2d.Flow;

/**
	Base class for switchable lobby sub-views.
	Each sub-view creates its own domkit Flow design and assigns it to `design`.
**/
class SubView extends Object
{
	/** The domkit design attached by LobbyView into the sub-view container. */
	public var design : Flow;

	public function new(?parent : Object)
	{
		super(parent);
	}
}