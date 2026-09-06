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
	var mag : Float = 0;
	/** Move speed, world units/sec (cdb "Hero"."speed"). */
	var speed : Float;
	/** Jump impulse, world units/sec (cdb "Hero"."jumpVelocity"). */
	var jumpVel : Float;
	/** Ground check: ray length below the feet (cdb "Hero"."groundProbe"). */
	var groundProbe : Float;
	/** True while the hero is airborne — steering disabled (request). */
	var airborne : Bool = false;
	/** Seconds after a jump during which ground contact is ignored (the
		physics tick may not have stepped yet — without this the hero
		re-grounds instantly and keeps air control). */
	var airLock : Float = 0;
	static inline var JUMP_AIR_LOCK : Float = 0.2;
	// cached cdb numbers (ray/spawn math needs them every tick)
	var heroR : Float;
	var heroHH : Float;

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Hero");
		speed = gd.f("Hero", "speed", 6);
		jumpVel = gd.f("Hero", "jumpVelocity", 5.5);
		groundProbe = gd.f("Hero", "groundProbe", 0.12);
		heroR = gd.f("Hero", "heroRadius", 0.4);
		heroHH = gd.f("Hero", "heroHalfHeight", 0.45);
		bus.subscribe(HeroMoveIntent, onIntent);
		spawnHero();
	}

	function onIntent(e : HeroMoveIntent) : Void
	{
		dirX = e.dirX;
		dirZ = e.dirZ;
		yaw = e.yaw;
		mag = e.mag;
		if (e.jump) tryJump();
	}

	/** Create the hero capsule resting on the floor at the origin. */
	public function spawnHero() : Void
	{
		// capsule total height = 2*(hh + r); spawn so the bottom touches the floor
		var b = sim.phys.spawnBody(RigidBodyType._DYNAMIC, new Vec3(0, heroR + heroHH + SPAWN_MARGIN, 0), "hero")
			.addShape(new CapsuleGeometry(heroR, heroHH), null, null, 0.0, 0.6)
			.setRotationFactor(0, 1, 0); // can't topple: pitch/roll locked, only yaw
		sim.setHero(b);
	}

	/** Apply the latest movement intent to the hero body. */
	override public function update(dt : Float) : Void
	{
		if (sim.hero == null) return;

		if (airLock > 0) airLock -= dt;

		var grounded = isGrounded();
		if (grounded && airLock <= 0) airborne = false;

		// while airborne the hero is NOT steerable (request): keep the
		// velocity from the jump/last ground frame untouched
		if (airborne) return;

		// horizontal velocity from the intent, scaled by eased magnitude
		// (0..1 — smooth accel/decel from the client's input smoothing);
		// Y left to gravity/contacts
		var vx = dirX * speed * mag;
		var vz = dirZ * speed * mag;
		var v = sim.hero.body.getLinearVelocity();
		sim.hero.setLinearVelocity(vx, v.y, vz);

		// face the camera yaw: rotation around Y, forward = -Z at yaw 0.
		// Oimo Quat has no euler ctor — build the axis-angle quat directly.
		var ha = yaw * 0.5;
		sim.hero.body.setOrientation(new oimo.common.Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
	}

	/** One-shot jump: impulse up when standing on something. */
	function tryJump() : Void
	{
		if (sim.hero == null || airborne || airLock > 0 || !isGrounded()) return;
		airborne = true;
		airLock = JUMP_AIR_LOCK;
		var v = sim.hero.body.getLinearVelocity();
		sim.hero.setLinearVelocity(v.x, jumpVel, v.z);
	}

	/** True when the capsule bottom is within `groundProbe` of a surface. */
	function isGrounded() : Bool
	{
		var p = sim.hero.getPosition();
		// from the center straight down, just past the capsule bottom
		// (bottom = center - (r + hh)); a tiny extra avoids self-hit jitter
		var hit = sim.phys.rayCast(p.x, p.y, p.z, p.x, p.y - heroR - heroHH - groundProbe, p.z);
		// ignore a self-hit: the ray starts inside our own capsule
		return hit != null && hit.body != sim.hero;
	}
}
