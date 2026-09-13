package serv.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.BulletHit;
import shared.net.GameNet;
import shared.systems.System;

/**
	Server-only transport layer: subscribes to ONE-SHOT events on the room's
	shared bus and forwards them to the clients via GameNet RPCs.

	Continuous state (positions, HP) is NOT routed here — it replicates via
	HeroObject `@:s` fields. Only events: bullet spawn broadcasts (so remote
	clients spawn the projectile deterministically), authoritative hit
	verdicts (server's BulletSystem -> every client logs the same CLIENT HIT),
	later damage feedback.

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
		bus.subscribe(BulletHit, onBulletHit);
	}

	function onBulletFire(e : BulletFired) : Void
	{
		if (gameNet != null)
			gameNet.bulletSpawn(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
	}

	function onBulletHit(e : BulletHit) : Void
	{
		// single server-side record of the verdict; then everyone logs it
		trace('SERVER HIT ' + e.victimId + ' at '
			+ Math.round(e.x * 100) / 100 + ','
			+ Math.round(e.y * 100) / 100 + ','
			+ Math.round(e.z * 100) / 100);
		if (gameNet != null)
			gameNet.bulletHit(e.ownerId, e.victimId, e.x, e.y, e.z);
	}

	// TODO: subscribe to the damage/PlayerDamaged event → gameNet.damage(...)

	override public function dispose() : Void
	{
		bus.unsubscribe(BulletFired, onBulletFire);
		bus.unsubscribe(BulletHit, onBulletHit);
		gameNet = null;
		super.dispose();
	}
}