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

/**
	Network -> local bus: a player joined this game room (server-assigned id).
	Published by RoomNetSystem when the GameNet mirror's playerJoined rpc
	arrives. Consumers use it for HUD / own-pid bookkeeping.
**/
class PlayerJoined
{
	public var playerId : String;
	public var name : String;

	public function new(playerId : String, name : String)
	{
		this.playerId = playerId;
		this.name = name;
	}
}

/**
	Network -> local bus: a REMOTE bullet was spawned (server broadcast).
	The owner spawned it locally already and skips its echo; others spawn it
	deterministically (BulletSystem.spawnBullet). Published by RoomNetSystem
	from the GameNet mirror's bulletSpawn rpc.
**/
class BulletSpawned
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
	Server-authoritative hit verdict -> local bus: a bullet (ownerId) hit
	something (victimId = hero pid, or a world body name like "floor"/"cube")
	at world-space (x, y, z). Published ONLY by the server's BulletSystem
	via the GameNet mirror's bulletHit rpc; clients log it (CLIENT HIT) and
	use it as a fallback to destroy the matching local bullet.
**/
class BulletHit
{
	public var ownerId : String;
	public var victimId : String;
	public var x : Float;
	public var y : Float;
	public var z : Float;

	public function new(ownerId : String, victimId : String, x : Float, y : Float, z : Float)
	{
		this.ownerId = ownerId;
		this.victimId = victimId;
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

/**
	Local, SHOOTER's client only: this player's bullet landed on something.
	Published by GamePlayView when a BulletHit verdict arrives with
	ownerId == ownPid — the shooter gets its hit-confirm feedback.
	victimId = hero pid, or a world body name ("floor"/"cube").
**/
class ShooterHit
{
	public var shooterId : String;
	public var victimId : String;
	public var x : Float;
	public var y : Float;
	public var z : Float;

	public function new(shooterId : String, victimId : String, x : Float, y : Float, z : Float)
	{
		this.shooterId = shooterId;
		this.victimId = victimId;
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

/**
	Local, VICTIM's client only: a bullet hit THIS player, and shooterId names
	who fired it. Published by GamePlayView when a BulletHit verdict arrives
	with victimId == ownPid — the victim learns its attacker.
**/
class VictimHit
{
	public var shooterId : String;
	public var victimId : String;
	public var x : Float;
	public var y : Float;
	public var z : Float;

	public function new(shooterId : String, victimId : String, x : Float, y : Float, z : Float)
	{
		this.shooterId = shooterId;
		this.victimId = victimId;
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

/**
	Network -> local bus: a player took damage (instant UI feedback; the
	authoritative HP arrives via the HeroObject `@:s` delta). Published by
	RoomNetSystem from the GameNet mirror's damage rpc.
**/
class PlayerDamaged
{
	public var playerId : String;
	public var amount : Float;

	public function new(playerId : String, amount : Float)
	{
		this.playerId = playerId;
		this.amount = amount;
	}
}