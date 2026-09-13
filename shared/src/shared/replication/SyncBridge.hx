#if sys
package shared.replication;

import oimo.common.Quat;

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

	/** The local player's own id — its body is prediction-driven, but the
		mirror is still PULLED to reconcile the prediction with the authority
		(server): small offsets converge smoothly, large ones snap. Server:
		irrelevant. Defaults to Player.LOCAL; the client sets it to its
		server id once discovered. */
	public var ownId : String = Player.LOCAL;

	/** Convergence rate for own-hero reconciliation (exp smoothing, /s). */
	static inline var RECONCILE_RATE : Float = 2.5;
	/** Errors below this (meters) are left to prediction (no tug). */
	static inline var RECONCILE_TOLERANCE : Float = 0.05;
	/** Errors above this (meters) snap — a stuck-on-obstacle desync must not
		stradle the view mechanics. */
	static inline var RECONCILE_SNAP_DIST : Float = 0.8;

	public function new(bus : EventBus, sim : SimWorld, isServer : Bool, ?gd : GameData)
	{
		super(bus, sim, gd, "SyncBridge");
		this.isServer = isServer;
	}

	override public function update(dt : Float) : Void
	{
		if (isServer) pushSimToNet();
		else pullNetToSim(dt);
	}

	/** Server: authoritative physics → HeroObject (sent to clients). */
	function pushSimToNet() : Void
	{
		for (id in sim.heroes.keys())
		{
			var obj = sim.heroEnts.get(id);
			if (obj == null) continue;
			var body = sim.heroes.get(id);
			var p = body.getPosition();
			obj.posX = p.x;
			obj.posY = p.y;
			obj.posZ = p.z;
			// yaw: inverse of HeroSystem.apply's orientation setter. The hero's
			// rotation is locked to pitch/roll (rotationFactor 0,1,0), so the
			// quat is a pure Y rotation: q = (0, sin(-yaw/2), 0, cos(yaw/2))
			// → yaw = -2 * atan2(q.y, q.w).
			var q = body.body.getOrientation();
			obj.yaw = -2 * Math.atan2(q.y, q.w);
		}
	}

	/** Client: mirror → hero body. Remote heroes are puppets (hard-set).
		The own hero keeps local prediction but RECONCILES against the server
		authority: small offsets ease back, large ones (collision desync) snap —
		so the local view converges to what everyone else sees. The own body is
		keyed Player.LOCAL in sim.heroes on the client, while `ownId` is the
		server-assigned pid — match either, but ALWAYS reconcile vs ownId's mirror. */
	function pullNetToSim(dt : Float) : Void
	{
		for (id in sim.heroes.keys())
		{
			var isOwn = id == Player.LOCAL || id == ownId;
			var obj = isOwn ? sim.heroEnts.get(ownId) : sim.heroEnts.get(id);
			if (obj == null) continue;
			var body = sim.heroes.get(id);
			if (body == null) continue;

			if (isOwn)
			{
				var p = body.getPosition();
				var ex = obj.posX - p.x, ey = obj.posY - p.y, ez = obj.posZ - p.z;
				var dist = Math.sqrt(ex * ex + ey * ey + ez * ez);
				if (dist > RECONCILE_SNAP_DIST)
					body.setPosition(obj.posX, obj.posY, obj.posZ); // big desync: correct
				else if (dist > RECONCILE_TOLERANCE)
				{
					var k = 1.0 - Math.exp(-RECONCILE_RATE * dt);
					body.setPosition(p.x + ex * k, p.y + ey * k, p.z + ez * k);
				}
				continue; // yaw stays from local camera input
			}

			// remote: face the owner's view yaw — same rotation form
			// HeroSystem.apply uses, so the capsule turns toward where the
			// player aims. Remote bodies have no HeroSystem state (puppets) —
			// nothing overwrites this between pulls.
			var ha = obj.yaw * 0.5;
			body.setPosition(obj.posX, obj.posY, obj.posZ);
			body.body.setOrientation(new Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
		}
	}
}
#end