package shared;

import oimo.common.Vec3;

import phys.GameWorld;
import phys.core.IPhysics;
import phys.core.PhysBody;
import phys.core.PhysCore;

import shared.GameData;
import shared.IUpdate;
import shared.events.EventBus;
import shared.systems.Systems;

class SimWorld implements IUpdate
{

	/** The physics world (unified interface — any consumer can use it). */
	public var phys(default, null) : IPhysics;

	/** The concrete physics core (exposes `interpol` for render-side interpolation). */
	public var physCore(default, null) : PhysCore;

	/**
		Side-specific entity factory — the ONLY way bodies are spawned
		(`factory.spawnCube` / `spawnHeroBody` / `spawnBulletBody` / `spawnLevel`)
		and the only hook that fires when a body enters the world
		(`factory.onBodyAdded`: client binds a mesh, server does nothing).
		Systems read it as `sim.factory` — never build bodies inline.
	**/
	public var factory(default, null) : IEntityFactory;

	/** true on the headless server sim — the authority: owns and replicates
		net objects (HeroSystem), emits authoritative hit verdicts. False on
		every client (prediction/puppets read mirrors, never own them). */
	public var isServer(default, null) : Bool;

	/** Player hero bodies keyed by playerId (spawned by HeroSystem). */
	public var heroes(default, null) : Map<String, PhysBody>;

	#if sys
	/** Network entities keyed by playerId — server: owned HeroObjects,
		client: mirrors (Pattern A). Synced by SyncBridge, not game systems. */
	public var heroEnts(default, null) : Map<String, shared.net.HeroObject> = new Map();
	#end

	/** Convenience: the local player's hero body (or null). */
	public var hero(get, never) : Null<PhysBody>;
	inline function get_hero() : Null<PhysBody> return heroes.get(Player.LOCAL);

	/** Game database (cdb) — all tunables are queried from it. */
	public var gd(default, null) : GameData;

	/** Event bus: simulation systems communicate only through it. */
	public var bus(default, null) : EventBus;

	/** Simulation systems — advanced inside update(), identically on client and server. */
	public var systems(default, null) : Systems;

	var spawnT : Float;
	var spawnI : Int;

	/**
		@param gd game database; null -> empty (Config defaults used).
		All tunables (gravity, floor, cubes, hero capsule) are read per-sheet.
		@param bus app event bus; null -> local-only EventBus.
		@param server true on the headless server sim — makes BulletSystem the
		authoritative hit detector (publishes BulletHit verdicts to be broadcast).
		@param factory the side-specific entity factory (Server headless vs
		Client meshes). Defaults to the shared BaseEntityFactory (no visuals).
	**/
	public function new(?gd : GameData, ?bus : EventBus, ?server : Bool = false,
		?factory : IEntityFactory = null)
	{
		this.gd = gd != null ? gd : new GameData();
		this.bus = bus != null ? bus : new EventBus();
		this.factory = factory != null ? factory : new BaseEntityFactory();
		isServer = server;
		heroes = new Map();
		systems = new Systems();
		var world = new GameWorld(new Vec3(0, gravityY(), 0));
		world.phys.setPhysicsHz(Config.PHYSICS_HZ);
		phys = world.phys;
		physCore = cast world.phys;
		spawnT = 0;
		spawnI = 0;
		// gameplay systems (sim == this: direct world access; gd for cdb queries)
		systems.add(new shared.systems.HeroSystem(bus, this, gd));
		systems.add(new shared.systems.BulletSystem(bus, this, gd, server));
	}

	// --- cdb accessors (all data lives in the base — required reads) ---

	public inline function gravityY() : Float return gd.req("World", "gravityY");
	public inline function floorHalf() : Float return gd.req("World", "floorHalf");
	public inline function cubeSize() : Float return gd.req("World", "cubeSize");
	public inline function cubeSpawnInterval() : Float return gd.req("World", "cubeSpawnInterval");

	/**
		Build the static level geometry through the factory (floor + prefab
		obstacles). Called AFTER any side resources exist that onBodyAdded
		needs — the client must have its renderer bound to the factory first,
		so meshes can be parented/bound while the level spawns.
	**/
	public function buildLevel() : Void
	{
		factory.spawnLevel(this);
	}

	/** Register a player hero body under `playerId`. Called by HeroSystem. */
	public function setHero(playerId : String, b : PhysBody) : Void
	{
		// register the key BEFORE onSpawn fires so consumers can tell the
		// local hero apart from later remote spawns (sim.hero == body)
		heroes.set(playerId, b);
		add(b);
	}

	/** Despawn a player hero body (server: peer disconnect; client: mirror
		removed). Releases the physics body; world consumers unbind the mesh. */
	public function removeHero(playerId : String) : Void
	{
		var b = heroes.get(playerId);
		if (b == null) return;
		heroes.remove(playerId);
		phys.removeBody(b);
	}

	/**
		Advance the simulation and run gameplay rules (auto-spawn).
		The SAME call is made by client and server every frame/tick.
	**/
	public function update(dt : Float) : Void
	{
		phys.step(dt);

		spawnT -= dt;
		if (spawnT <= 0) {
			spawnT = cubeSpawnInterval();
			spawnI++;
			var x = (spawnI % 3) * 1.2 - 1.2;
			factory.spawnCube(this, new Vec3(x, 6, 0));
		}

		systems.update(dt);
	}

	/**
		Register a body in the world and notify the factory's onBodyAdded
		(the client draws it via its factory). Systems spawn through
		`factory.spawnX` — those already route body creation through here.
	**/
	public function add(b : PhysBody) : PhysBody
	{
		phys.addBody(b);
		factory.onBodyAdded(b);
		return b;
	}
}
