package shared;

import oimo.collision.geometry.CapsuleGeometry;
import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;

import phys.GameWorld;
import phys.core.IPhysics;
import phys.core.PhysBody;

import shared.GameData;
import shared.IUpdate;

class SimWorld implements IUpdate
{

	/** The physics world (unified interface — any consumer can use it). */
	public var phys(default, null) : IPhysics;

	/** Called when a body is spawned, so a consumer can attach visuals/logic. */
	public var onSpawn : Null<PhysBody -> Void>;

	/** Hero body in the world (spawned in buildLevel). */
	public var hero(default, null) : PhysBody;

	/** Game database (cdb) — all tunables are queried from it. */
	public var gd(default, null) : GameData;

	var spawnT : Float;
	var spawnI : Int;

	/**
		@param gd game database; null -> empty (Config defaults used).
		All tunables (gravity, floor, cubes, hero capsule) are read per-sheet.
	**/
	public function new(?gd : GameData)
	{
		this.gd = gd != null ? gd : new GameData();
		var world = new GameWorld(new Vec3(0, gravityY(), 0));
		world.phys.setPhysicsHz(Config.PHYSICS_HZ);
		phys = world.phys;
		spawnT = 0;
		spawnI = 0;
		buildLevel();
	}

	// --- cdb accessors (Config defaults when the sheet/field is absent) ---

	inline function gravityY() : Float return gd.f("World", "gravityY", Config.GRAVITY_Y);
	inline function floorHalf() : Float return gd.f("World", "floorHalf", Config.FLOOR_HALF);
	inline function cubeSize() : Float return gd.f("World", "cubeSize", Config.CUBE_SIZE);
	inline function cubeSpawnInterval() : Float return gd.f("World", "cubeSpawnInterval", Config.CUBE_SPAWN_INTERVAL);
	inline function heroRadius() : Float return gd.f("Hero", "heroRadius", 0.4);
	inline function heroHalfHeight() : Float return gd.f("Hero", "heroHalfHeight", 0.45);

	/** Static level geometry. Extend with walls/props as needed. */
	function buildLevel() : Void
	{
		add(phys.spawnBody(RigidBodyType._STATIC, new Vec3(0, -0.5, 0), "floor")
			.addBox(floorHalf(), 0.25, floorHalf()));

		// hero prototype: dynamic capsule that can slide/push but never topples
		// (angular factor (0,1,0) locks pitch/roll — only yaw spins are free)
		var heroR = heroRadius();
		hero = add(phys.spawnBody(RigidBodyType._DYNAMIC, new Vec3(0, heroR + 0.01, 0), "hero")
			.addShape(new CapsuleGeometry(heroR, heroHalfHeight()), null, null, 0.0, 0.6)
			.setRotationFactor(0, 1, 0));
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
