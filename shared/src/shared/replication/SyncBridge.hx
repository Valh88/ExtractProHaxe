#if sys
package shared.replication;

import oimo.common.Quat;
import haxe.Timer;

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

	Remote heroes use snapshot-based interpolation (rendered ~120ms behind
	real-time) to flatten jitter and avoid teleport artifacts at high latency.
**/
class SyncBridge extends System
{
	/** true = server (push), false = client (pull). */
	var isServer : Bool;

	/** The local player's own id — its body is prediction-driven, but the
		mirror is still PULLED to reconcile the prediction with the authority
		(server). Server: irrelevant. Defaults to Player.LOCAL; the client
		sets it to its server id once discovered. */
	public var ownId : String = Player.LOCAL;

	// --- own-hero reconciliation ---
	/** Errors above this (meters) snap — a REAL desync (collision mismatch,
		tunnel) must not stradle the view mechanics. During normal movement
		and at rest the client is NOT corrected at all: the simulation is
		deterministic on both ends, the server receives the same intents and
		stops on its own a ping later. Pulling toward the mirror (which is
		~ping stale) at stop/cruise fights a moving target and produces the
		visible "spring back" — so it is deliberately removed. */
	static inline var RECONCILE_SNAP_DIST : Float = 3.0;

	// --- puppet interpolation (remote heroes) ---
	/** Seconds behind real-time that puppet positions are rendered. This
		flattens network jitter at the cost of visual delay. At 150ms ping
		this absorbs most of the jitter without noticeable lag. */
	static inline var INTERP_DELAY : Float = 0.12;
	/** Max snapshot entries kept per puppet (ring buffer). 8 snapshots at
		30Hz = ~267ms of history — more than enough for INTERP_DELAY. */
	static inline var SNAPSHOT_MAX : Int = 8;

	var puppetSnaps : Map<String, Array<{px:Float, py:Float, pz:Float, yaw:Float, t:Float}>>;

	public function new(bus : EventBus, sim : SimWorld, isServer : Bool, ?gd : GameData)
	{
		super(bus, sim, gd, "SyncBridge");
		this.isServer = isServer;
		puppetSnaps = new Map();
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
			var q = body.body.getOrientation();
			obj.yaw = -2 * Math.atan2(q.y, q.w);
		}
	}

	/** Client: mirror → hero body.
		Own hero: prediction runs locally, reconciliation ONLY at rest.
		Remote heroes: snapshot-based interpolation (lerp between historical
		mirror positions offset by INTERP_DELAY). */
	function pullNetToSim(dt : Float) : Void
	{
		var now = Timer.stamp();
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
				// No reconciliation at rest or during movement — the server
				// mirror is stale by ~ping and easing toward it makes the
				// stopped hero "spring" first forward (server still cruising
				// before it got the stop intent) then back (fresh snapshot
				// behind prediction). The deterministic sim + identical
				// intents converge the body by itself; only a REAL desync
				// (stuck in a wall, tunnel) snaps.
				if (dist > RECONCILE_SNAP_DIST)
					body.setPosition(obj.posX, obj.posY, obj.posZ);
				continue;
			}

			// --- remote hero: interpolated puppet ---
			var snaps = puppetSnaps.get(id);
			if (snaps == null)
			{
				snaps = [];
				puppetSnaps.set(id, snaps);
			}
			snaps.push({px: obj.posX, py: obj.posY, pz: obj.posZ, yaw: obj.yaw, t: now});
			while (snaps.length > SNAPSHOT_MAX) snaps.shift();

			var targetT = now - INTERP_DELAY;
			var i = snaps.length - 1;
			while (i > 0 && snaps[i].t > targetT) i--;

			if (i < snaps.length - 1 && snaps.length >= 2)
			{
				var a = snaps[i], b = snaps[i + 1];
				var span = b.t - a.t;
				var f = span > 0.001 ? (targetT - a.t) / span : 0;
				f = f < 0 ? 0 : f > 1 ? 1 : f;
				body.setPosition(
					a.px + (b.px - a.px) * f,
					a.py + (b.py - a.py) * f,
					a.pz + (b.pz - a.pz) * f
				);
				var dy = b.yaw - a.yaw;
				if (dy > Math.PI) dy -= Math.PI * 2;
				if (dy < -Math.PI) dy += Math.PI * 2;
				var iy = a.yaw + dy * f;
				var ha = iy * 0.5;
				body.body.setOrientation(new Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
			}
			else
			{
				body.setPosition(obj.posX, obj.posY, obj.posZ);
				var ha = obj.yaw * 0.5;
				body.body.setOrientation(new Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
			}
		}
	}
}
#end
