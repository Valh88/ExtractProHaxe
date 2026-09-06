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
	sphere projectile at the requested position flying along the direction,
	and removes it on the first collision (console print on hit).

	Sim system (sim != null): mutates the world directly; runs inside
	SimWorld.update() identically on client and server.
**/
class BulletSystem extends System
{
	// cached cdb numbers
	var radius : Float;
	var speed : Float;
	var cooldown : Float;

	// fire cooldown state
	var cd : Float = 0;
	/** Bullets flagged by contact callbacks — destroyed after phys.step. */
	var pending : Array<PhysBody> = [];
	
	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Bullet");
		radius = gd.req("Bullet", "radius");
		speed = gd.req("Bullet", "speed");
		cooldown = gd.req("Bullet", "cooldown");
		bus.subscribe(BulletFired, onFire);
	}

	function onFire(e : BulletFired) : Void
	{
		if (cd > 0) return; // rate limit
		cd = cooldown;

		// create (not spawn: must go through sim.add so the client view
		// gets onSpawn and draws the mesh) then add via the sim
		var b = sim.phys.createBody(RigidBodyType._DYNAMIC, new Vec3(e.x, e.y, e.z), "bullet")
			.addSphere(radius, null, 0.0, 0.5)
			.setGravityScale(0) // straight-flying projectile: no gravity
			.setLinearVelocity(e.dirX * speed, e.dirY * speed, e.dirZ * speed);
		sim.add(b);
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
		// deferred destruction: SimWorld runs systems AFTER phys.step, so
		// removing here is safe (outside the solver)
		if (pending.length > 0)
		{
			for (b in pending) sim.phys.removeBody(b);
			pending.resize(0);
		}
	}
}
