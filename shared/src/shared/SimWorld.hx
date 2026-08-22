package shared;

import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;

import phys.GameWorld;
import phys.core.IPhysics;
import phys.core.PhysBody;

import shared.Config;

class SimWorld
{

	/** The physics world (unified interface — any consumer can use it). */
	public var phys(default, null) : IPhysics;

	/** Called when a body is spawned, so a consumer can attach visuals/logic. */
	public var onSpawn : Null<PhysBody -> Void>;

	var spawnT : Float;
	var spawnI : Int;

	public function new()
	{
		var world = new GameWorld(new Vec3(0, Config.GRAVITY_Y, 0));
		world.phys.setPhysicsHz(Config.PHYSICS_HZ);
		phys = world.phys;
		spawnT = 0;
		spawnI = 0;
		buildLevel();
	}

	/** Static level geometry. Extend with walls/props as needed. */
	function buildLevel() : Void
	{
		add(phys.spawnBody(RigidBodyType._STATIC, new Vec3(0, -0.5, 0), "floor")
			.addBox(Config.FLOOR_HALF, 0.25, Config.FLOOR_HALF));
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
			spawnT = Config.CUBE_SPAWN_INTERVAL;
			spawnI++;
			var x = (spawnI % 3) * 1.2 - 1.2;
			spawnCube(new Vec3(x, 6, 0));
		}
	}

	/** Spawn a dynamic cube at `pos`. Returns the body (already in world). */
	public function spawnCube(pos : Vec3) : PhysBody
	{
		var h = Config.CUBE_SIZE * 0.5;
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
