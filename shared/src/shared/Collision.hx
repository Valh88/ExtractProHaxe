package shared;

/**
	Collision layers (bits) for `PhysBody.setGroup()` / `setMask()`.

	Oimo rule: two shapes collide only if `a.group & b.mask` AND
	`b.group & a.mask` are BOTH non-zero. Group = layers this body belongs
	to; mask = layers it interacts with.

	Matrix:
	- bullet <-> cubes/floor: YES   (BULLET vs WORLD|ALL)
	- bullet <-> hero:        NO    (player's own bullet never hits themself)
	- bullet <-> bullet:      NO
	- hero  <-> cubes/floor:  YES

	Structural constants (not cdb tunables) — identical on client and
	server, keeping simulations deterministic. Future multiplayer: per-owner
	ignore (a bullet should only skip its SHOOTER's hero, not everyone's)
	moves into contact callbacks with an owner id; the layer approach is
	the right base for single-hero and still correct for the server.
**/
class Collision
{
	public static inline var HERO : Int = 1 << 0;
	public static inline var WORLD : Int = 1 << 1; // floor, cubes, static props
	public static inline var BULLET : Int = 1 << 2;

	/** Everything — used by world geometry masks. */
	public static inline var ALL : Int = HERO | WORLD | BULLET;
}
