package shared;

import oimo.common.Vec3;

import phys.core.PhysBody;

import shared.events.EventBus;

/**
	Side-specific factory of ENTITIES in the shared simulation.

	SimWorld is the deterministic, UI-less world. The factory is the ONE place
	that decides HOW a side materializes it:

	- creates + owns the world (`createWorld`) — SimWorld keeps the factory
	  and passes ITSELF to the simulation systems, so both sides run the
	  exact same systems on the exact same world;
	- spawns every body through the SAME recipes (BaseEntityFactory), so the
	  physics can never diverge between client and server;
	- is notified on body enter/leave (`onBodyAdded`/`onBodyRemoved`) so it
	  can attach/remove side-specific resources (Server: nothing; Client: a
	  h3d mesh via `meshForBody`).

	Systems and SimWorld spawn bodies ONLY through `sim.factory` — never
	inline — so a new entity type is added in exactly one place per side.
**/
interface IEntityFactory
{
	/** Create + own the world for this side. The world sets `SimWorld.factory`
		to `this` and passes itself to its systems. Caller then calls
		`world.buildLevel()` (level spawn may need side resources first, e.g.
		the client's renderer must exist before meshes can be bound). */
	public function createWorld(?gd : GameData, ?bus : EventBus, server : Bool) : SimWorld;

	/** Spawn the static level geometry (floor + prefab obstacles). */
	public function spawnLevel(world : SimWorld) : Void;

	/** Spawn a dynamic cube at `pos`. Returns the body (already in world). */
	public function spawnCube(world : SimWorld, pos : Vec3) : PhysBody;

	/** Spawn a hero capsule for `playerId`. Returns the body NOT yet keyed —
		HeroSystem registers it via `sim.setHero` (which adds it to the world). */
	public function spawnHeroBody(world : SimWorld, playerId : String) : PhysBody;

	/** Spawn a bullet projectile at (x,y,z) flying along dir. Returns the body
		NOT yet added — BulletSystem adds it (and wires callbacks) itself. */
	public function spawnBulletBody(world : SimWorld, ownerId : String,
		x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : PhysBody;

	/** A body entered the world — attach side-specific visuals/logic. */
	public function onBodyAdded(b : PhysBody) : Void;

	/** A body left the world — release side-specific resources. */
	public function onBodyRemoved(b : PhysBody) : Void;
}