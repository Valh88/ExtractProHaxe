package shared.systems;

import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;
import oimo.collision.geometry.CapsuleGeometry;

import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.GameData;
import shared.systems.System;

/**
	Simulation system owning the player hero. Spawns the hero capsule on
	init; applies client movement intents (HeroMoveIntent) to the body each
	tick — identically on client and server, so simulations stay in sync.

	Sim system (sim != null): may mutate the world directly; runs inside
	SimWorld.update() in fixed order on client and server alike.
**/
class HeroSystem extends System
{
	static inline var SPAWN_MARGIN : Float = 0.01; // spawn slightly above floor

	// last received intent
	var dirX : Float = 0;
	var dirZ : Float = 0;
	var yaw : Float = 0;
	/** Move speed, world units/sec (cdb "Hero"."speed"). */
	var speed : Float;

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Hero");
		speed = gd.f("Hero", "speed", 6);
		bus.subscribe(HeroMoveIntent, onIntent);
		spawnHero();
	}

	function onIntent(e : HeroMoveIntent) : Void
	{
		dirX = e.dirX;
		dirZ = e.dirZ;
		yaw = e.yaw;
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

	/** Apply the latest movement intent to the hero body. */
	override public function update(dt : Float) : Void
	{
		if (sim.hero == null) return;

		// horizontal velocity from the intent (Y left to gravity/contacts)
		var vx = dirX * speed;
		var vz = dirZ * speed;
		var v = sim.hero.body.getLinearVelocity();
		sim.hero.setLinearVelocity(vx, v.y, vz);

		// face the camera yaw: rotation around Y, forward = -Z at yaw 0.
		// Oimo Quat has no euler ctor — build the axis-angle quat directly.
		var ha = yaw * 0.5;
		sim.hero.body.setOrientation(new oimo.common.Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
	}
}
