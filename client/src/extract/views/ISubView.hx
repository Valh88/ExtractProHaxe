package extract.views;

import h2d.Object;

/** A switchable lobby sub-view: exposes the domkit design it attaches. */
interface ISubView
{
	public var design(get, never) : Object;
}