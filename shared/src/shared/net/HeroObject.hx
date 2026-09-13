package shared.net;

import rnl.net.NetworkSerializable;

/**
	Per-player game entity, replicated server→clients via @:s dirty deltas.

	This is the ONLY container of a hero's game data (Pattern A): HP, weapon,
	ammo, score and a copy of the authoritative position. The server owns it
	(creates + `net.add`s), clients receive a mirror and read it directly —
	they never write to it (that would fight the server's dirty bits).

	Position is a COPY from the Oimo PhysBody (the physics engine owns the
	transform); copied each tick by SyncBridge, not by game systems.
**/
class HeroObject extends NetworkSerializable
{
	@:s public var playerId : String = "";

	/** Display name of the player. Carried on the object so every client can
		identify ITS OWN HeroObject by name (own-pid discovery) at ADD time —
		no extra RPC, immune to join timing. */
	@:s public var name : String = "";

	// position — copy of the authoritative PhysBody transform (SyncBridge)
	@:s public var posX : Float = 0;
	@:s public var posY : Float = 0;
	@:s public var posZ : Float = 0;
	@:s public var yaw : Float = 0;

	// game data — lives HERE and only here
	@:s public var hp : Float = 100;
	@:s public var maxHp : Float = 100;
	@:s public var weaponId : Int = 0;
	@:s public var ammo : Int = 0;
	@:s public var score : Int = 0;

	public function new(?playerId : String)
	{
		super();
		this.playerId = playerId != null ? playerId : "";
		// loss-tolerant channel: dropped position deltas are overwritten
		// by the next tick's SYNC — state, not critical events.
		__syncChannel = 1;
	}
}