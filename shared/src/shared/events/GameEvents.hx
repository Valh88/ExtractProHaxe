package shared.events;

/** Fired when a player pressed SEARCH in the lobby. */
class SearchStarted
{
	public var mode : String;

	public function new(mode : String)
	{
		this.mode = mode;
	}
}

/**
	Client -> sim shooting intent: world-space spawn position (hero eye) and
	normalized fire direction. The sim (BulletSystem) spawns the projectile.
	`ownerId` names the shooter (own spawn is skipped on its client when the
	server broadcasts the same bullet back).
**/
class BulletFired
{
	public var ownerId : String;
	public var x : Float;
	public var y : Float;
	public var z : Float;
	public var dirX : Float;
	public var dirY : Float;
	public var dirZ : Float;

	public function new(ownerId : String, x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float)
	{
		this.ownerId = ownerId;
		this.x = x;
		this.y = y;
		this.z = z;
		this.dirX = dirX;
		this.dirY = dirY;
		this.dirZ = dirZ;
	}
}

/**
	Client -> sim movement intent: world-space move direction (normalized
	horizontal), eased magnitude 0..1 (smooth accel/decel), the desired
	body yaw (camera yaw) and a one-shot jump request. Published only when
	state changes; the sim (HeroSystem) applies it each tick.
	`playerId` routes the intent to the right hero (local = "local"; in the
	future each connected client passes its own id).
**/
class HeroMoveIntent
{
	public var playerId : String;
	public var dirX : Float;
	public var dirZ : Float;
	public var yaw : Float;
	public var mag : Float;
	/** One-shot jump request (consumed by the sim on delivery). */
	public var jump : Bool;

	public function new(playerId : String, dirX : Float, dirZ : Float, yaw : Float, mag : Float, jump : Bool)
	{
		this.playerId = playerId;
		this.dirX = dirX;
		this.dirZ = dirZ;
		this.yaw = yaw;
		this.mag = mag;
		this.jump = jump;
	}
}