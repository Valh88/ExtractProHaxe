package serv.factory;

import phys.core.PhysBody;

import shared.BaseEntityFactory;

/**
	Headless server entity factory: the shared recipes, NO visuals.
	onBodyAdded/onBodyRemoved are no-ops — future server-only entity
	side-effects (state logging, gizmos, sweepers) hook here.
**/
class ServerEntityFactory extends BaseEntityFactory
{
	public function new() {}

	override public function onBodyAdded(b : PhysBody) : Void {}

	override public function onBodyRemoved(b : PhysBody) : Void {}
}