package shared.systems;

import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;
import oimo.collision.geometry.CapsuleGeometry;

import shared.events.EventBus;
import shared.GameData;
import shared.systems.System;

/**
	Simulation system owning the player hero. Spawns the hero capsule on init
	and is the future home for input-driven movement (receive intents via the
	bus, apply to sim.hero each tick).

	Sim system (sim != null): may mutate the world directly; runs inside
	SimWorld.update() in fixed order on client and server alike.
**/
class HeroSystem extends System
{
	static inline var SPAWN_MARGIN : Float = 0.01; // spawn slightly above floor

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Hero");
		spawnHero();
	}

	/** Create the hero capsule resting on the floor at the origin. */
	public function spawnHero() : Void
	{
		var r = gd.f("Hero", "heroRadius", 0.4);
		var hh = gd.f("Hero", "heroHalfHeight", 0.45);
		var b = sim.phys.spawnBody(RigidBodyType._DYNAMIC, new Vec3(0, r + SPAWN_MARGIN, 0), "hero")
			.addShape(new CapsuleGeometry(r, hh), null, null, 0.0, 0.6)
			.setRotationFactor(0, 1, 0); // can't topple: pitch/roll locked, only yaw
		sim.setHero(b);
	}

	/** Per-tick behaviour (movement) lands here. */
	override public function update(dt : Float) : Void
	{
	}
}
