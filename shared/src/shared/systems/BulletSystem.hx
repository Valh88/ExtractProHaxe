package shared.systems;

import oimo.common.Vec3;

import phys.core.PhysBody;

import shared.SimWorld;
import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.BulletHit;
import shared.systems.System;

/**
	Simulation system for hero shooting. Subscribes to BulletFired, spawns a
	sphere projectile at the requested position flying along the direction
	(no gravity), and removes it on hit or lifetime expiry.

	Hit detection — two paths, one VERDICT:
	- WORLD hits (floor/cubes): a CONVEX-CAST sweep of the bullet sphere
	  along each tick's travel segment. At realistic speeds (150-200 m/s =
	  5-6.7 m per 30 Hz tick) discrete physics contacts miss thin cubes
	  entirely (the bullet jumps over them), so the continuous sweep is the
	  reliable path and the ONLY one that emits the verdict. The physical
	  contact callback is kept as a destroy-only safety net (mid-solve
	  removal must stay deferred, and it double-checks spawn-inside cases).
	- HERO hits are NOT physical (bullets pass through heroes by design, so
	  the shooter never self-blocks): a swept sphere-vs-capsule test against
	  `sim.heroes` runs in EVERY sim and destroys the bullet at the same
	  deterministic point (the local shooter + remote clients see it vanish).
	  Only the server (`isServer`) turns a hero hit into a BulletHit verdict.

	The owner's own hero is ALWAYS skipped (a bullet never registers a hit on
	the player who fired it). Verdicts are published solely from the server ->
	ServerTransportSystem broadcasts them -> every client logs one CLIENT HIT
	per authoritative hit.

	Sim system (sim != null): mutates the world directly; runs inside
	SimWorld.update() identically on client and server.
**/

/** A live bullet: its body, owner, sweep-from position, and hit/lifetime state. */
typedef BulletRec = {
	var b : PhysBody;
	var t : Float;
	var ownerId : String;
	var pX : Float;
	var pY : Float;
	var pZ : Float;
	var hit : Bool;
}

class BulletSystem extends System
{
	// cached cdb numbers
	var radius : Float;
	var cooldown : Float;
	/** Seconds a bullet lives without hitting anything (cdb "Bullet"."lifetime"). */
	var lifetime : Float;
	// cached hero capsule dims (swept hit test needs them every tick)
	var heroR : Float;
	var heroHH : Float;

	/** True on the server sim: emits authoritative BulletHit verdicts. */
	var isServer : Bool;

	/** Bullet-sized sphere swept along each tick's travel segment (world hits). */
	var worldSweep : oimo.collision.geometry.SphereGeometry;

	// fire cooldown state
	var cd : Float = 0;
	/** Bullets flagged by contact callbacks — destroyed after phys.step. */
	var pending : Array<PhysBody> = [];
	/** Live bullets with remaining lifetime, in spawn order. */
	var alive : Array<BulletRec> = [];

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData, ?server : Bool = false)
	{
		super(bus, sim, gd, "Bullet");
		radius = gd.req("Bullet", "radius");
		cooldown = gd.req("Bullet", "cooldown");
		lifetime = gd.req("Bullet", "lifetime");
		heroR = gd.req("Hero", "heroRadius");
		heroHH = gd.req("Hero", "heroHalfHeight");
		worldSweep = new oimo.collision.geometry.SphereGeometry(radius);
		isServer = server;
		bus.subscribe(BulletFired, onFire);
	}

	function onFire(e : BulletFired) : Void
	{
		if (cd > 0) return; // rate limit
		cd = cooldown;
		spawnBullet(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
	}

	/**
		Create a bullet at `pos` flying along the (normalized) direction and
		add it to the world. No cooldown — used both by onFire and for REMOTE
		spawns arriving via GameNet.bulletSpawn (a remote client calls this
		DIRECTLY, bypassing the bus so the event is not echoed back to the
		server). `ownerId` names the shooter — its hero is never a hit target.
	**/
	public function spawnBullet(ownerId : String, x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : Void
	{
    	// create (not spawn: the recipe comes from the factory, must go through
    	// sim.add so the client view gets onBodyAdded and draws the mesh)
    	var b = sim.factory.spawnBulletBody(sim, ownerId, x, y, z, dirX, dirY, dirZ);
    	sim.add(b);
		var rec : BulletRec = { b : b, t : lifetime, ownerId : ownerId, pX : x, pY : y, pZ : z, hit : false };
		alive.push(rec);
		// WORLD contact: destroy-only safety net (the swept convex-cast in
		// update() is the reliable hit path and the ONLY verdict source —
		// emitting here too would double-report whenever both paths fire for
		// the same crossing). Removing a body INSIDE the physics step
		// callback would mutate the world mid-solve, hence queue only.
		var recForCb = rec;
		b.setCollisionCallbacks(
			function(other : PhysBody, pos : Vec3, normal : Vec3, depth : Float)
			{
				queueDestroy(recForCb);
			},
			null, null, null
		);
	}

	/** Queue `rec`'s body for destruction after the current physics step. */
	function queueDestroy(rec : BulletRec) : Void
	{
		if (rec.hit) return;
		rec.hit = true;
		pending.push(rec.b);
	}

	/** Server-only: publish the authoritative hit verdict on the bus. */
	function emitHit(ownerId : String, victimId : String, x : Float, y : Float, z : Float) : Void
	{
		bus.publish(new BulletHit(ownerId, victimId, x, y, z));
	}

	/**
		Client fallback: destroy the (still flying) local bullet that the server
		just declared hit — identity is ownerId + nearest alive body, so even if
		the local swept test lagged a frame behind the server verdict, the
		projectile still vanishes. No-op when already destroyed.
	**/
	public function removeBulletByHit(ownerId : String, x : Float, y : Float, z : Float) : Void
	{
		var best = -1;
		var bestD = 1e30;
		for (i in 0...alive.length)
		{
			var a = alive[i];
			if (a.ownerId != ownerId || a.hit) continue;
			var p = a.b.getPosition();
			var dx = p.x - x, dy = p.y - y, dz = p.z - z;
			var d = dx * dx + dy * dy + dz * dz;
			if (d < bestD) { bestD = d; best = i; }
		}
		if (best >= 0) queueDestroy(alive[best]);
	}

	override public function update(dt : Float) : Void
	{
		if (cd > 0) cd -= dt;

		// hero swept hit test (every sim: deterministic destruction at the
		// same point; server additionally emits the authoritative verdict)
		for (a in alive)
		{
			if (a.hit) continue;
			var p = a.b.getPosition();
			var cx = p.x, cy = p.y, cz = p.z;
			// find the earliest hero hit along this step's travel segment
			var hitOwner : Null<String> = null;
			var bestT = 2.0;
			var hitX = 0.0, hitY = 0.0, hitZ = 0.0;
			for (pid in sim.heroes.keys())
			{
				if (pid == a.ownerId) continue; // ignore the shooter's own hero
				var hb = sim.heroes.get(pid);
				if (hb == null) continue;
				var hp = hb.getPosition();
				// capsule axis is vertical, from center±halfHeight
				var rsq = radius + heroR;
				var h = closestSegSeg(
					hp.x, hp.y - heroHH, hp.z,          // capsule bottom
					hp.x, hp.y + heroHH, hp.z,          // capsule top
					a.pX, a.pY, a.pZ, cx, cy, cz        // bullet travel segment
				);
				if (h.t >= 0 && h.t < bestT && h.d <= rsq)
				{
					bestT = h.t;
					hitOwner = pid;
					hitX = a.pX + (cx - a.pX) * h.t;
					hitY = a.pY + (cy - a.pY) * h.t;
					hitZ = a.pZ + (cz - a.pZ) * h.t;
				}
			}
			if (hitOwner != null)
			{
				queueDestroy(a);
				if (isServer) emitHit(a.ownerId, hitOwner, hitX, hitY, hitZ);
			}
			else
			{
				// WORLD swept hit: continuous sphere sweep over this tick's
				// travel segment — catches thin cubes the discrete contacts
				// skip at high speed. Heroes are ignored here (handled by the
				// deterministic test above, matching the BULLET->WORLD mask).
				var rec = a;
				var swept = false;
				sim.phys.convexCast(worldSweep, a.pX, a.pY, a.pZ,
					cx - a.pX, cy - a.pY, cz - a.pZ,
					function(wb : PhysBody, frac : Float, wpos : Vec3, n : Vec3)
					{
						if (wb == null || wb.name == "hero") return;
						swept = true;
						// authoritative verdict: server tells everyone what was hit
						if (isServer) emitHit(rec.ownerId, wb.name, wpos.x, wpos.y, wpos.z);
					});
				if (swept) queueDestroy(a);
			}
			// remember this position for the NEXT step's sweep
			a.pX = cx;
			a.pY = cy;
			a.pZ = cz;
		}

		// lifetime expiry (no hit within the cdb lifetime -> destroy)
		for (i in alive.length - 1...-1)
		{
			var a = alive[i];
			a.t -= dt;
			if (a.t <= 0) queueDestroy(a);
		}

		// deferred destruction: SimWorld runs systems AFTER phys.step, so
		// removing here is safe (outside the solver)
		if (pending.length > 0)
		{
			for (b in pending)
			{
				sim.phys.removeBody(b);
				// drop its lifetime record (identity scan — bullet count is small)
				for (j in 0...alive.length)
					if (alive[j].b == b) { alive.splice(j, 1); break; }
			}
			pending.resize(0);
		}
	}

	/**
		Closest point between segment A-B and segment C-D (unit-independent).
		Returns parametric `t` (on C-D, 0..1 when within) and the distance
		`d`. t == -1 means the segments effectively don't approach (degenerate).
	**/
	static function closestSegSeg(
		ax : Float, ay : Float, az : Float,
		bx : Float, by : Float, bz : Float,
		cx : Float, cy : Float, cz : Float,
		dx : Float, dy : Float, dz : Float
	) : { t : Float, d : Float }
	{
		var d1x = bx - ax, d1y = by - ay, d1z = bz - az;
		var d2x = dx - cx, d2y = dy - cy, d2z = dz - cz;
		var rx = ax - cx, ry = ay - cy, rz = az - cz;

		var a = d1x * d1x + d1y * d1y + d1z * d1z;
		var e = d2x * d2x + d2y * d2y + d2z * d2z;
		var f = d2x * rx + d2y * ry + d2z * rz;
		var s : Float, t : Float;

		if (a <= 1e-12 && e <= 1e-12)
		{
			s = 0; t = 0;
		}
		else if (a <= 1e-12)
		{
			s = 0; t = f < 0 ? 0 : (f > e ? 1 : f / e);
		}
		else
		{
			var c = d1x * rx + d1y * ry + d1z * rz;
			if (e <= 1e-12)
			{
				t = 0;
				s = c < 0 ? 0 : (c > a ? 1 : -c / a);
			}
			else
			{
				var bv = d1x * d2x + d1y * d2y + d1z * d2z;
				var denom = a * e - bv * bv;
				if (denom <= 1e-12)
				{
					s = c < 0 ? 0 : (c > a ? 1 : -c / a);
					t = 0;
				}
				else
				{
					s = (bv * f - c * e) / denom;
					if (s < 0) s = 0; else if (s > 1) s = 1;
					t = (bv * s + f) / e;
					if (t < 0)
					{
						t = 0;
						s = c < 0 ? 0 : (c > a ? 1 : -c / a);
					}
					else if (t > 1)
					{
						t = 1;
						s = (bv - c) / a;
						if (s < 0) s = 0; else if (s > 1) s = 1;
					}
				}
			}
		}

		// closest points
		var p1x = ax + d1x * s, p1y = ay + d1y * s, p1z = az + d1z * s;
		var p2x = cx + d2x * t, p2y = cy + d2y * t, p2z = cz + d2z * t;
		var dx2 = p1x - p2x, dy2 = p1y - p2y, dz2 = p1z - p2z;
		var d = Math.sqrt(dx2 * dx2 + dy2 * dy2 + dz2 * dz2);
		return { t : t, d : d };
	}
}