package shared.net;

import rnl.net.NetworkSerializable;

/**
	Shared game-play RPC facade. One instance is `add`ed on the server (its
	owner, per game room) and mirrored to every connected client.

	Server -> clients: hero position updates, bullet spawns.
	Clients -> server: position reports, fire requests.

	@:rpc(server) methods run only on the server (__isServer == true);
	@:rpc(clients) methods run on all connected clients.
**/
class GameNet extends NetworkSerializable
{
	/** Server handler: a player reported their position. */
	public var onPosition : Null<String -> Float -> Float -> Float -> Float -> Void> = null;

	/** Server handler: a player fired a bullet. */
	public var onFire : Null<String -> Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;

	/** Client handler: received a hero position update. */
	public var onHeroUpdate : Null<String -> Float -> Float -> Float -> Float -> Void> = null;

	/** Client handler: received a bullet spawn. */
	public var onBulletSpawn : Null<Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;

	public function new()
	{
		super();
	}

	// --- Client -> server RPCs ---

	/** Client -> server: local hero position + yaw (sent each sim tick). */
	@:rpc(server)
	public function sendPosition(playerId : String, x : Float, y : Float, z : Float, yaw : Float) : Void
	{
		if (onPosition != null) onPosition(playerId, x, y, z, yaw);
	}

	/** Client -> server: fire a bullet from position in direction. */
	@:rpc(server)
	public function fireBullet(playerId : String, x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : Void
	{
		if (onFire != null) onFire(playerId, x, y, z, dirX, dirY, dirZ);
	}

	// --- Server -> client RPCs ---

	/** Server -> clients: a hero moved to a new position. */
	@:rpc(clients)
	public function heroUpdate(playerId : String, x : Float, y : Float, z : Float, yaw : Float) : Void
	{
		if (onHeroUpdate != null) onHeroUpdate(playerId, x, y, z, yaw);
	}

	/** Server -> clients: a bullet was spawned. */
	@:rpc(clients)
	public function bulletSpawn(x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : Void
	{
		if (onBulletSpawn != null) onBulletSpawn(x, y, z, dirX, dirY, dirZ);
	}
}
