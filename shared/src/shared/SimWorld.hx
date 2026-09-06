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

	/** Hero body (spawned by HeroSystem). */
	public var hero(default, null) : PhysBody;

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
	**/
	public function new(?gd : GameData, ?bus : EventBus)
	{
		this.gd = gd != null ? gd : new GameData();
		this.bus = bus != null ? bus : new EventBus();
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
			.addBox(floorHalf(), 0.25, floorHalf()));
	}

	/** Called by systems (HeroSystem) that spawn the hero. */
	public function setHero(b : PhysBody) : Void
	{
		hero = add(b);
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
			.addBox(h, h, h, null, 0.7, 0.7));
	}

	/** All bodies currently in the world (for initial view building). */
	public function existingBodies() : Array<PhysBody>
	{
		return phys.getBodies();
	}

	function add(b : PhysBody) : PhysBody
	{
		phys.addBody(b);
		if (onSpawn != null) onSpawn(b);
		return b;
	}
}
