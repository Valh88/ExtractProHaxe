#if sys
package shared.net;

import rnl.net.NetworkSerializable;

/**
	Shared game-play RPC facade. One instance is `add`ed on the server (its
	owner, per game room) and mirrored to every connected client.

	Events ONLY — continuous state (positions, HP) lives in per-entity
	`HeroObject` (`@:s` fields), not here. GameNet carries one-shot events:

	Clients -> server: input intents (`heroInput`), fire requests.
	Server -> clients: bullet spawns, damage feedback (instant UI).

	@:rpc(server) methods run only on the server (__isServer == true);
	@:rpc(clients) methods run on all connected clients.
**/
class GameNet extends NetworkSerializable
{
	/** Server handler: a player's movement input intent. The playerId is NOT
	passed by the client — the server resolves it from the RPC caller
	(`__rpcCaller` -> peer -> playerByPeer) so it can never spoof another
	player's id. */
	public var onHeroInput : Null<Float -> Float -> Float -> Float -> Bool -> Void> = null;

	/** Server handler: a player fired a bullet. PlayerId resolved server-side. */
	public var onFire : Null<Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;

	/** Client handler: received a bullet spawn. `ownerId` = the shooter —
		its own client spawned it locally via BulletFired already and skips. */
	public var onBulletSpawn : Null<String -> Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;

	/** Client handler: a player joined this game room (server-assigned id).
		Each client finds its OWN id by matching `name` (prototype convention). */
	public var onPlayerJoined : Null<String -> String -> Void> = null;

	/** Client handler: received a damage feedback (instant UI). */
	public var onDamage : Null<String -> Float -> Void> = null;

	/** Client handler: server-authoritative hit verdict (owner fired, victim
		= hero pid or world body name, world-space impact point). */
	public var onBulletHit : Null<String -> String -> Float -> Float -> Float -> Void> = null;

	/** Client handler: authoritative sun phase from the server's SunSyncSystem
		(sunAngle 0..2π, 0 = noon peak, + dayLength in seconds per full cycle).
		Clients keep advancing the phase locally between syncs (dead reckoning). */
	public var onSunUpdate : Null<Float -> Float -> Void> = null;

	public function new()
	{
		super();
	}

	// --- Client -> server RPCs ---

	/** Client -> server: input intent (prediction runs locally, server
		simulates the authoritative position into the player's HeroObject).
		No playerId arg: the server resolves the caller's id from __rpcCaller. */
	@:rpc(server)
	public function heroInput(dirX : Float, dirZ : Float, yaw : Float, mag : Float, jump : Bool) : Void
	{
		if (onHeroInput != null) onHeroInput(dirX, dirZ, yaw, mag, jump);
	}

	/** Client -> server: fire a bullet from position in direction.
		No playerId arg: the server resolves the caller's id from __rpcCaller. */
	@:rpc(server)
	public function fireBullet(x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : Void
	{
		if (onFire != null) onFire(x, y, z, dirX, dirY, dirZ);
	}

	// --- Server -> client RPCs ---

	/** Server -> clients: a bullet was spawned (owner spawned it locally; the
		others spawn it deterministically from this origin). */
	@:rpc(clients)
	public function bulletSpawn(ownerId : String, x : Float, y : Float, z : Float, dirX : Float, dirY : Float, dirZ : Float) : Void
	{
		if (onBulletSpawn != null) onBulletSpawn(ownerId, x, y, z, dirX, dirY, dirZ);
	}

	/** Server -> clients: a player joined this game room (server-assigned id). */
	@:rpc(clients)
	public function playerJoined(playerId : String, name : String) : Void
	{
		if (onPlayerJoined != null) onPlayerJoined(playerId, name);
	}

	/** Server -> clients: a player took damage (instant UI feedback; the
		authoritative HP arrives via the HeroObject `@:s` delta). */
	@:rpc(clients)
	public function damage(playerId : String, amount : Float) : Void
	{
		if (onDamage != null) onDamage(playerId, amount);
	}

	/** Server -> clients: a bullet hit something. `victimId` = hero pid, or a
		world body name ("floor"/"cube"). Clients log the verdict and destroy
		their matching local bullet (fallback). */
	@:rpc(clients)
	public function bulletHit(ownerId : String, victimId : String, x : Float, y : Float, z : Float) : Void
	{
		if (onBulletHit != null) onBulletHit(ownerId, victimId, x, y, z);
	}

	/** Server -> clients: authoritative sun phase (SunSyncSystem broadcasts it
		periodically; clients dead-reckon locally between syncs). */
	@:rpc(clients)
	public function sunUpdate(sunAngle : Float, dayLength : Float) : Void
	{
		if (onSunUpdate != null) onSunUpdate(sunAngle, dayLength);
	}
}
#end