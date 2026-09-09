package serv.room;

import shared.GameData;
import serv.systems.LobbyStateSystem;

/**
	Lobby room — the room WITHOUT a world: players just sit in a menu/ready-up
	screen, so there is no physics to step. It inherits the shared Room
	lifecycle (state, bus, roomSystems) but is created with `withWorld=false`,
	so `world` stays null and `tick` only drives the room's own logic.

	Skeleton for future matchmaking: join/leave/ready, with a roster of
	LobbyPlayers. When the lobby fills/ready-up completes, a real game room
	(MapRoom) would be spawned by the host from here.
**/
class LobbyRoom extends Room
{
	/** Players sitting in this lobby keyed by player id. */
	public var players(default, null) : Map<String, LobbyPlayer>;

	public function new(id : String, gd : GameData)
	{
		super(id, "lobby", gd, false); // worldless: no SimWorld, no physics
		players = new Map();
		roomSystems.add(new LobbyStateSystem(bus, this));
	}

	/** Add a player to the lobby. Returns false if the id is already inside. */
	public function join(playerId : String, ?name : String) : Bool
	{
		if (players.exists(playerId)) return false;
		players.set(playerId, new LobbyPlayer(playerId, name));
		trace('LOBBY "' + id + '" join ' + playerId
			+ ' (players=' + Lambda.count(players) + ')');
		return true;
	}

	/** Remove a player from the lobby. */
	public function leave(playerId : String) : Bool
	{
		if (!players.exists(playerId)) return false;
		players.remove(playerId);
		trace('LOBBY "' + id + '" leave ' + playerId
			+ ' (players=' + Lambda.count(players) + ')');
		return true;
	}

	/** Set a player's ready flag. */
	public function setReady(playerId : String, ready : Bool) : Bool
	{
		var p = players.get(playerId);
		if (p == null) return false;
		p.setReady(ready);
		trace('LOBBY "' + id + '" ready ' + playerId + '=' + ready);
		return true;
	}
}