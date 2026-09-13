package shared;

import oimo.collision.geometry.CapsuleGeometry;
import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;

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

	/** Called when a body is spawned, so a consumer can attach visuals/logic. */
	public var onSpawn : Null<PhysBody -> Void>;

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
	**/
	public function new(?gd : GameData, ?bus : EventBus, ?server : Bool = false)
	{
		this.gd = gd != null ? gd : new GameData();
		this.bus = bus != null ? bus : new EventBus();
		heroes = new Map();
		systems = new Systems();
		var world = new GameWorld(new Vec3(0, gravityY(), 0));
		world.phys.setPhysicsHz(Config.PHYSICS_HZ);
		phys = world.phys;
		physCore = cast world.phys;
		spawnT = 0;
		spawnI = 0;
		buildLevel();
		// gameplay systems (sim == this: direct world access; gd for cdb queries)
		systems.add(new shared.systems.HeroSystem(bus, this, gd));
		systems.add(new shared.systems.BulletSystem(bus, this, gd, server));
	}

	// --- cdb accessors (all data lives in the base — required reads) ---

	public inline function gravityY() : Float return gd.req("World", "gravityY");
	public inline function floorHalf() : Float return gd.req("World", "floorHalf");
	public inline function cubeSize() : Float return gd.req("World", "cubeSize");
	public inline function cubeSpawnInterval() : Float return gd.req("World", "cubeSpawnInterval");

	/** Static level geometry. Extend with walls/props as needed. */
	function buildLevel() : Void
	{
		add(phys.spawnBody(RigidBodyType._STATIC, new Vec3(0, -0.5, 0), "floor")
			.addBox(floorHalf(), 0.25, floorHalf())
			.setGroup(Collision.WORLD).setMask(Collision.ALL));

		// static obstacles from the hide-authored prefab — the SAME bodies must
		// exist on client and server, or collisions desync (the client had the
		// pillars, the server simulated straight through them).
		// Path: client = resource (hxd.Res), server = filesystem relative to
		// the run CWD (repo root).
		var pp = new PrefabPhysics(phys);
	#if heapsphysics_render
		var statics = pp.load("levels/test.prefab");
	#else
		var statics = pp.load("client/res/levels/test.prefab");
	#end
		for (s in statics) add(s);
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
			spawnCube(new Vec3(x, 6, 0));
		}

		systems.update(dt);
	}

	/** Spawn a dynamic cube at `pos`. Returns the body (already in world). */
	public function spawnCube(pos : Vec3) : PhysBody
	{
		var h = cubeSize() * 0.5;
		return add(phys.spawnBody(RigidBodyType._DYNAMIC, pos, "cube")
			.addBox(h, h, h, null, 0.7, 0.7)
			.setGroup(Collision.WORLD).setMask(Collision.ALL));
	}

	/** All bodies currently in the world (for initial view building). */
	public function existingBodies() : Array<PhysBody>
	{
		return phys.getBodies();
	}

	/**
		Register a body in the world and notify onSpawn (the client draws it).
		Systems must spawn through this (with phys.createBody) — bodies added
		via phys.spawnBody directly never reach the client's view.
	**/
	public function add(b : PhysBody) : PhysBody
	{
		phys.addBody(b);
		if (onSpawn != null) onSpawn(b);
		return b;
	}
}
