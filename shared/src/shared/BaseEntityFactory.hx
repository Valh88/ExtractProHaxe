package shared;

import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;
import oimo.collision.geometry.CapsuleGeometry;
import oimo.collision.geometry.SphereGeometry;

import phys.core.PhysBody;

import shared.events.EventBus;

/**
	Shared entity recipes — the body CREATION both sides must agree on
	(determinism: SimWorld is simulated identically on client and server, so
	a shape/group/mask that differs anywhere desyncs the physics).

	Client and server factories extend this; only the body enter/leave hooks
	differ (Server: nothing; Client: a h3d mesh). Headless use: instantiate
	this class directly (its lifecycle hooks are empty no-ops).
**/
class BaseEntityFactory implements IEntityFactory
{
	/** Spawn capsules so their bottom touches the floor. */
	static inline var SPAWN_MARGIN : Float = 0.01;

	/** The world this factory created + owns (set by createWorld). */
	public var world(default, null) : Null<SimWorld>;

	public function new() {}

	public function createWorld(?gd : GameData, ?bus : EventBus, server : Bool) : SimWorld
	{
		return world = new SimWorld(gd, bus, server, this);
	}

	public function spawnLevel(world : SimWorld) : Void
	{
		world.add(world.phys.spawnBody(RigidBodyType._STATIC, new Vec3(0, -0.5, 0), "floor")
			.addBox(world.floorHalf(), 0.25, world.floorHalf())
			.setGroup(Collision.WORLD).setMask(Collision.ALL));

		// static obstacles from the hide-authored prefab — the SAME bodies must
		// exist on client and server, or collisions desync (the client had the
		// pillars, the server simulated straight through them).
		// Path: client = resource (hxd.Res), server = filesystem relative to
		// the run CWD (repo root).
		var pp = new PrefabPhysics(world.phys);
	#if heapsphysics_render
		var statics = pp.load("levels/test.prefab");
	#else
		var statics = pp.load("client/res/levels/test.prefab");
	#end
		for (s in statics) world.add(s);
	}

	public function spawnCube(world : SimWorld, pos : Vec3) : PhysBody
	{
		var h = world.cubeSize() * 0.5;
		return world.add(world.phys.spawnBody(RigidBodyType._DYNAMIC, pos, "cube")
			.addBox(h, h, h, null, 0.7, 0.7)
			.setGroup(Collision.WORLD).setMask(Collision.ALL));
	}

	public function spawnHeroBody(world : SimWorld, playerId : String) : PhysBody
	{
		var heroR = world.gd.req("Hero", "heroRadius");
		var heroHH = world.gd.req("Hero", "heroHalfHeight");
		// capsule total height = 2*(hh + r); spawn so the bottom touches the floor.
		// HERO layer; mask without BULLET: player's own bullets ignore them
		return world.phys.createBody(RigidBodyType._DYNAMIC, new Vec3(0, heroR + heroHH + SPAWN_MARGIN, 0), "hero")
			.addShape(new CapsuleGeometry(heroR, heroHH), null, null, 0.0, 0.6)
			.setRotationFactor(0, 1, 0) // can't topple: pitch/roll locked, only yaw
			.setGroup(Collision.HERO).setMask(Collision.WORLD);
	}

	public function spawnBulletBody(world : SimWorld, ownerId : String,
		x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : PhysBody
	{
		// BULLET layer, WORLD mask: hits floor/cubes, ignores ALL heroes
		// (incl. the shooter — hero hits are detected separately, swept)
		var radius = world.gd.req("Bullet", "radius");
		var speed = world.gd.req("Bullet", "speed");
		return world.phys.createBody(RigidBodyType._DYNAMIC, new Vec3(x, y, z), "bullet")
			.addSphere(radius, null, 0.0, 0.5)
			.setGravityScale(0) // straight-flying projectile: no gravity
			.setGroup(Collision.BULLET).setMask(Collision.WORLD)
			.setLinearVelocity(dirX * speed, dirY * speed, dirZ * speed);
	}

	public function onBodyAdded(b : PhysBody) : Void {}

	public function onBodyRemoved(b : PhysBody) : Void {}
}