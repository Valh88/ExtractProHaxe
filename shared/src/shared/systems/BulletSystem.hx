package shared.systems;

import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;
import oimo.collision.geometry.SphereGeometry;

import phys.core.PhysBody;

import shared.SimWorld;
import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.BulletFired;
import shared.systems.System;

/**
	Simulation system for hero shooting. Subscribes to BulletFired, spawns a
	sphere projectile at the requested position flying along the direction
	(no gravity, HERO-immune via collision layers), and removes it on the
	first collision or when its lifetime expires (cdb "Bullet"."lifetime").

	Sim system (sim != null): mutates the world directly; runs inside
	SimWorld.update() identically on client and server.
**/
class BulletSystem extends System
{
	// cached cdb numbers
	var radius : Float;
	var speed : Float;
	var cooldown : Float;
	/** Seconds a bullet lives without hitting anything (cdb "Bullet"."lifetime"). */
	var lifetime : Float;

	// fire cooldown state
	var cd : Float = 0;
	/** Bullets flagged by contact callbacks — destroyed after phys.step. */
	var pending : Array<PhysBody> = [];
	/** Live bullets with remaining lifetime, in spawn order. */
	var alive : Array<{ b : PhysBody, t : Float }> = [];

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Bullet");
		radius = gd.req("Bullet", "radius");
		speed = gd.req("Bullet", "speed");
		cooldown = gd.req("Bullet", "cooldown");
		lifetime = gd.req("Bullet", "lifetime");
		bus.subscribe(BulletFired, onFire);
	}

	function onFire(e : BulletFired) : Void
	{
		if (cd > 0) return; // rate limit
		cd = cooldown;

		// create (not spawn: must go through sim.add so the client view
		// gets onSpawn and draws the mesh) then add via the sim.
		// BULLET layer, WORLD mask: hits floor/cubes, ignores the HERO
		// (player's own bullet never collides with themself)
		var b = sim.phys.createBody(RigidBodyType._DYNAMIC, new Vec3(e.x, e.y, e.z), "bullet")
			.addSphere(radius, null, 0.0, 0.5)
			.setGravityScale(0) // straight-flying projectile: no gravity
			.setGroup(Collision.BULLET).setMask(Collision.WORLD)
			.setLinearVelocity(e.dirX * speed, e.dirY * speed, e.dirZ * speed);
		sim.add(b);
		alive.push({ b : b, t : lifetime });
		// first contact with anything: queue for destruction — removing a
		// body INSIDE the physics step callback would mutate the world mid-solve
		b.setCollisionCallbacks(
			function(other : PhysBody, pos : Vec3, normal : Vec3, depth : Float)
			{
				if (pending.indexOf(b) < 0) pending.push(b);
				trace("BULLET HIT " + (other != null ? other.name : "?") + " at "
					+ Math.round(b.getPosition().x * 100) / 100 + ","
					+ Math.round(b.getPosition().y * 100) / 100 + ","
					+ Math.round(b.getPosition().z * 100) / 100);
			},
			null, null, null
		);
	}

	override public function update(dt : Float) : Void
	{
		if (cd > 0) cd -= dt;

		// lifetime expiry (10 s without a hit -> destroy)
		var i = alive.length - 1;
		while (i >= 0)
		{
			var a = alive[i];
			a.t -= dt;
			if (a.t <= 0)
			{
				alive.splice(i, 1);
				sim.phys.removeBody(a.b);
			}
			i--;
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
}
