package serv.room;

import shared.GameData;
import shared.net.NetConfig;
import shared.net.PlayerInfo;

import serv.systems.LobbyStateSystem;
import serv.systems.NetRoomSystem;

/**
	Lobby room — the room WITHOUT a world: players just sit in a menu/ready-up
	screen, so there is no physics to step. It inherits the shared Room
	lifecycle (state, bus, roomSystems) but is created with `withWorld=false`,
	so `world` stays null and `tick` only drives the room's own logic.

	Networking (prototype): a `NetRoomSystem` in `roomSystems` owns this
	lobby's RNL `SocketHost` (its own UDP socket) and shared `LobbyNet` facade.
	The system polls the socket each tick and routes incoming `@:rpc` calls
	(join/setReady) to the handlers wired below.
**/
class LobbyRoom extends Room
{
	/** Players sitting in this lobby keyed by player id. */
	public var players(default, null) : Map<String, LobbyPlayer>;

	/** The lobby's networking system (owns the socket + net facade). */
	public var netSys(default, null) : Null<NetRoomSystem>;

	/** peerId (local RNL id) -> playerId, populated on join. */
	var playerByPeer : Map<Int, String> = new Map();

	/** Counter to generate stable ids for auto-joined players. */
	var nextPlayerId : Int = 1;

	public function new(id : String, gd : GameData, ?port : Int)
	{
		super(id, "lobby", gd, false); // worldless: no SimWorld, no physics
		players = new Map();

		// --- networking (prototype): the socket lives in a room system ---
		var p = port != null ? port : NetConfig.LOBBY_PORT;
		netSys = new NetRoomSystem(bus, gd, p);
		netSys.onJoin = name -> handleJoin(name);
		netSys.onSetReady = v -> handleSetReady(v);
		netSys.onAnnounce = text -> trace('LOBBY "' + id + '" announce: ' + text);
		netSys.onPeerConnect = peerId -> trace('LOBBY "' + id + '" peer connect id=' + peerId);
		netSys.onPeerDisconnect = peerId -> {
			trace('LOBBY "' + id + '" peer disconnect id=' + peerId);
			var drop = playerByPeer.get(peerId);
			if (drop != null) leave(drop);
		};
		roomSystems.add(netSys);

		roomSystems.add(new LobbyStateSystem(bus, this));
	}

	/** Add a player to the lobby. Returns false if the id is already inside. */
	public function join(playerId : String, ?name : String) : Bool
	{
		if (players.exists(playerId)) return false;
		players.set(playerId, new LobbyPlayer(playerId, name));
		trace('LOBBY "' + id + '" join ' + playerId
			+ ' (players=' + Lambda.count(players) + ')');
		broadcastRoster();
		return true;
	}

	/** Remove a player from the lobby. */
	public function leave(playerId : String) : Bool
	{
		if (!players.exists(playerId)) return false;
		players.remove(playerId);
		for (peer in playerByPeer.keys())
			if (playerByPeer.get(peer) == playerId) playerByPeer.remove(peer);
		trace('LOBBY "' + id + '" leave ' + playerId
			+ ' (players=' + Lambda.count(players) + ')');
		broadcastRoster();
		return true;
	}

	/** Set a player's ready flag. */
	public function setReady(playerId : String, ready : Bool) : Bool
	{
		var p = players.get(playerId);
		if (p == null) return false;
		p.setReady(ready);
		trace('LOBBY "' + id + '" ready ' + playerId + '=' + ready);
		broadcastRoster();
		return true;
	}

	/** Handle a join RPC from a client (peer identity is best-effort for now). */
	function handleJoin(name : String) : Void
	{
		var pid = "p" + (nextPlayerId++);
		join(pid, name);
	}

	function handleSetReady(v : Bool) : Void
	{
		// prototype: toggle ready on every joined player (no per-peer mapping)
		for (pid in players.keys())
			setReady(pid, v);
	}

	/** Push the current roster to all connected clients via @:rpc(clients). */
	function broadcastRoster() : Void
	{
		if (netSys == null) return;
		var arr : Array<PlayerInfo> = [];
		for (pid in players.keys())
		{
			var p = players.get(pid);
			arr.push(new PlayerInfo(p.id, p.name, p.ready));
		}
		trace('LOBBY "' + id + '" roster -> ' + arr.length + ' players');
		netSys.broadcastRoster(arr);
	}
}

