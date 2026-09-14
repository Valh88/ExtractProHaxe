package shared.systems;

import phys.core.PhysBody;

import shared.Player;
import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.EntityNetSpawned;
import shared.events.GameEvents.EntityNetRemoved;
import shared.GameData;
import shared.systems.System;

/**
	Simulation system owning ALL player heroes. Spawns a hero capsule per
	player, applies each player's movement intents (HeroMoveIntent) to their
	own body every tick — identically on client and server, so simulations
	stay in sync.

	Per-player movement state lives in `states`, keyed by playerId; the body
	itself is registered in `sim.heroes`. The client emits HeroMoveIntent
	with its own id (single-player prototype: Player.LOCAL). Extend by calling
	spawnHero(id) for each connected remote player.

	Sim system (sim != null): may mutate the world directly; runs inside
	SimWorld.update() in fixed order on client and server alike.
**/

/** Movement input + jump lock state for one player. */
typedef HeroState = {
	var dirX : Float;
	var dirZ : Float;
	var yaw : Float;
	var mag : Float;
	/** True while the hero is airborne — steering disabled (request). */
	var airborne : Bool;
	/** Seconds after a jump during which ground contact is ignored (the
		physics tick may not have stepped yet — without this the hero
		re-grounds instantly and keeps air control). */
	var airLock : Float;
}

class HeroSystem extends System
{
	static inline var JUMP_AIR_LOCK : Float = 0.2;

	/** Move speed, world units/sec (cdb "Hero"."speed"). */
	var speed : Float;
	/** Jump impulse, world units/sec (cdb "Hero"."jumpVelocity"). */
	var jumpVel : Float;
	/** Ground check: ray length below the feet (cdb "Hero"."groundProbe"). */
	var groundProbe : Float;
	/** Velocity easing rate — exponential smoothing toward the intent
		target each tick (cdb "Controller"."moveSmooth"). */
	var smooth : Float;
	// cached cdb numbers (ray/spawn math needs them every tick)
	var heroR : Float;
	var heroHH : Float;

	/** Per-player hero state (input snapshot + jump lock), keyed by playerId. */
	var states : Map<String, HeroState> = new Map();

	public function new(bus : EventBus, sim : SimWorld, ?gd : GameData)
	{
		super(bus, sim, gd, "Hero");
		speed = gd.req("Hero", "speed");
		jumpVel = gd.req("Hero", "jumpVelocity");
		groundProbe = gd.req("Hero", "groundProbe");
		smooth = gd.req("Controller", "moveSmooth");
		heroR = gd.req("Hero", "heroRadius");
		heroHH = gd.req("Hero", "heroHalfHeight");
		bus.subscribe(HeroMoveIntent, onIntent);
	}

	/** Get (or create) the movement state for a player. */
	static function state(states : Map<String, HeroState>, playerId : String) : HeroState
	{
		var s = states.get(playerId);
		if (s == null)
		{
			s = { dirX : 0, dirZ : 0, yaw : 0, mag : 0, airborne : false, airLock : 0 };
			states.set(playerId, s);
		}
		return s;
	}

	/** Zero a player's movement intent immediately (used by the client to
		freeze the hero when the settings menu opens — must run BEFORE the
		physics step so `apply()` sees the cleared state). */
	public function clearIntent(playerId : String) : Void
	{
		var s = states.get(playerId);
		if (s != null)
		{
			s.dirX = 0;
			s.dirZ = 0;
			s.mag = 0;
		}
	}

	function onIntent(e : HeroMoveIntent) : Void
	{
		var s = state(states, e.playerId);
		s.dirX = e.dirX;
		s.dirZ = e.dirZ;
		s.yaw = e.yaw;
		s.mag = e.mag;
		if (e.jump) tryJump(e.playerId, s);
	}

	/**
		Create a hero capsule resting on the floor at the origin and register
		it under `playerId` (defaults to the local player). Called once per
		connected player.

		`simulated` = HeroSystem drives the body from input intents each tick
		(has a movement state). Server: pass true for every player (default).
		Client: pass false for REMOTE heroes — they are puppets owned by the
		SyncBridge mirror (position + yaw pulled from the server every tick);
		a state would make apply() overwrite the pulled orientation/velocity.
	**/
	public function spawnHero(?playerId : String, simulated : Bool = true, ?name : String = "") : Void
	{
		if (playerId == null) playerId = Player.LOCAL;
		var b = sim.factory.spawnHeroBody(sim, playerId);
		sim.setHero(playerId, b);
		// make sure the player has a movement state so update() runs for it
		if (simulated) state(states, playerId);
	#if sys
		// server owns the replicated HeroObject: create it here (lifecycle),
		// keep the world map as the single storage and notify the room's
		// transport via the bus (EntityNetSpawned → socket.add). Client
		// mirrors NEVER reach this path — the client sim is not the server.
		if (sim.isServer)
		{
			var obj = new shared.net.HeroObject(playerId);
			obj.name = name;
			obj.hp = 100;
			obj.maxHp = 100;
			sim.heroEnts.set(playerId, obj);
			bus.publish(new EntityNetSpawned(playerId));
		}
    #end
	}

	/** Despawn a player hero (server: disconnect; client: mirror removed). */
	public function removeHero(playerId : String) : Void
	{
		states.remove(playerId);
    #if sys
		// release the replicated object: notify the transport FIRST (so it
		// can socket.remove while the object is still in the map), then
		// remove from the world map. On the client the mirror is already
		// gone from findObjects — no-op here.
		if (sim.isServer)
		{
			var obj = sim.heroEnts.get(playerId);
			if (obj != null)
			{
				bus.publish(new EntityNetRemoved(playerId));
				sim.heroEnts.remove(playerId);
			}
		}
    #end
		sim.removeHero(playerId);
	}

	/** Apply the latest movement intent of every player to their hero body. */
	override public function update(dt : Float) : Void
	{
		for (id in states.keys())
		{
			var body = sim.heroes.get(id);
			if (body == null) continue; // state may outlive a respawn
			apply(states.get(id), body, dt);
		}
	}

	function apply(s : HeroState, body : PhysBody, dt : Float) : Void
	{
		if (s.airLock > 0) s.airLock -= dt;

		var grounded = isGrounded(body);
		if (grounded && s.airLock <= 0) s.airborne = false;

		// while airborne the hero is NOT steerable (request): keep the
		// velocity from the jump/last ground frame untouched
		if (s.airborne) return;

		// horizontal velocity from the intent, scaled by eased magnitude
		// (0..1 — smooth accel/decel from the client's input smoothing);
		// Y left to gravity/contacts.
		// Frame-rate independent exponential easing toward the target
		// prevents velocity snaps on landing: during air the body keeps
		// its physics velocity, and easing smoothly transitions to the
		// intended ground speed — the same feel as walk-start.
		var tx = s.dirX * speed * s.mag;
		var tz = s.dirZ * speed * s.mag;
		var v = body.body.getLinearVelocity();

		// A fully-zeroed intent (stop signal from opening the settings menu)
		// should halt the hero immediately — kill horizontal velocity outright
		// instead of the exponential easing tail that would otherwise let the
		// body coast a few extra steps. Yaw is still applied below (common path)
		// so the body keeps facing the camera even while standing still.
		if (s.mag == 0 && s.dirX == 0 && s.dirZ == 0)
		{
			body.setLinearVelocity(0, v.y, 0);
		}
		else
		{
			var k = 1.0 - Math.exp(-smooth * dt);
			body.setLinearVelocity(
				v.x + (tx - v.x) * k,
				v.y,
				v.z + (tz - v.z) * k
			);
		}

		// face the camera yaw: rotation around Y, forward = -Z at yaw 0.
		// Oimo Quat has no euler ctor — build the axis-angle quat directly.
		var ha = s.yaw * 0.5;
		body.body.setOrientation(new oimo.common.Quat(0, Math.sin(-ha), 0, Math.cos(ha)));
	}

	/** One-shot jump: impulse up when standing on something. */
	function tryJump(playerId : String, s : HeroState) : Void
	{
		var body = sim.heroes.get(playerId);
		if (body == null || s.airborne || s.airLock > 0 || !isGrounded(body)) return;
		s.airborne = true;
		s.airLock = JUMP_AIR_LOCK;
		var v = body.body.getLinearVelocity();
		body.setLinearVelocity(v.x, jumpVel, v.z);
	}

	/** True when `body`'s capsule bottom is within `groundProbe` of a surface. */
	function isGrounded(body : PhysBody) : Bool
	{
		var p = body.getPosition();
		// from the center straight down, just past the capsule bottom
		// (bottom = center - (r + hh)); a tiny extra avoids self-hit jitter
		var hit = sim.phys.rayCast(p.x, p.y, p.z, p.x, p.y - heroR - heroHH - groundProbe, p.z);
		// ignore a self-hit: the ray starts inside our own capsule
		return hit != null && hit.body != body;
	}
}