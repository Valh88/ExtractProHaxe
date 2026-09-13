package serv.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.BulletFired;
import shared.net.GameNet;
import shared.systems.System;

/**
	Server-only transport layer: subscribes to ONE-SHOT events on the room's
	shared bus and forwards them to the clients via GameNet RPCs.

	Continuous state (positions, HP) is NOT routed here — it replicates via
	HeroObject `@:s` fields. Only events: bullet spawn broadcasts (so remote
	clients spawn the projectile deterministically), later damage feedback.

	Wired by the room (Phase 6): `new ServerTransportSystem(bus, gd, gameNet)`.
**/
class ServerTransportSystem extends System
{
	var gameNet : Null<GameNet>;

	public function new(bus : EventBus, ?gd : GameData, gameNet : GameNet)
	{
		super(bus, null, gd, "ServerTransport");
		this.gameNet = gameNet;
		bus.subscribe(BulletFired, onBulletFire);
	}

	function onBulletFire(e : BulletFired) : Void
	{
		if (gameNet != null)
			gameNet.bulletSpawn(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
	}

	// TODO: subscribe to the damage/PlayerDamaged event → gameNet.damage(...)

	override public function dispose() : Void
	{
		bus.unsubscribe(BulletFired, onBulletFire);
		gameNet = null;
		super.dispose();
	}
}