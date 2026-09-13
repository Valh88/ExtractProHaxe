#if sys
package shared.replication;

import shared.Player;
import shared.SimWorld;
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/**
	The ONLY explicit copy of hero position (Oimo owns the PhysBody transform;
	it cannot be an `@:s` field). `isServer` decides the copy direction:

	- Server (`isServer == true`): authoritative physics body → HeroObject
	  (`@:s` fields), so dirty SYNCs flow down to the clients.
	- Client (`isServer == false`): mirror → remote hero body, so the
	  renderer/interpolation draws the remote player. The own body is skipped
	  (`ownId`) — its movement runs locally (prediction), applying the mirror
	  would yank the own body.

	HP/weapon/score are NOT copied here — systems write them straight into the
	`@:s` fields of HeroObject (dirty tracking is automatic in rnl).
**/
class SyncBridge extends System
{
	/** true = server (push), false = client (pull). */
	var isServer : Bool;

	/** The local player's own id — its body is prediction-driven and must
		never be pulled from a mirror (server: irrelevant). Defaults to
		Player.LOCAL; the client sets it to its server id once discovered. */
	public var ownId : String = Player.LOCAL;

	public function new(bus : EventBus, sim : SimWorld, isServer : Bool, ?gd : GameData)
	{
		super(bus, sim, gd, "SyncBridge");
		this.isServer = isServer;
	}

	override public function update(dt : Float) : Void
	{
		if (isServer) pushSimToNet();
		else pullNetToSim();
	}

	/** Server: authoritative physics → HeroObject (sent to clients). */
	function pushSimToNet() : Void
	{
		for (id in sim.heroes.keys())
		{
			var obj = sim.heroEnts.get(id);
			if (obj == null) continue;
			var p = sim.heroes.get(id).getPosition();
			obj.posX = p.x;
			obj.posY = p.y;
			obj.posZ = p.z;
			// yaw: extract from the PhysBody (Quat → angle around Y) — TODO (Q1)
		}
	}

	/** Client: mirror → remote hero body (for render interpolation).
		The own body is skipped (prediction owns it locally). */
	function pullNetToSim() : Void
	{
		for (id in sim.heroes.keys())
		{
			if (id == ownId) continue;
			var obj = sim.heroEnts.get(id);
			if (obj == null) continue;
			var body = sim.heroes.get(id);
			if (body == null) continue;
			body.setPosition(obj.posX, obj.posY, obj.posZ);
		}
	}
}
#end