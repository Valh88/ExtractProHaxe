package serv.room;

import shared.GameData;
import shared.net.PlayerInfo;

import serv.systems.LobbyStateSystem;

/**
	Lobby room — the room WITHOUT a world: players just sit in a menu/ready-up
	screen, so there is no physics to step. It inherits the shared Room
	lifecycle (state, bus, roomSystems, netSys) but is created with
	`withWorld=false`, so `world` stays null and `tick` only drives the
	room's own logic.

	Networking: the socket (NetRoomSystem) is created by the base Room.
	This subclass only wires lobby-specific RPC handlers (join/ready) and
	manages the player roster.
**/
class LobbyRoom extends Room
{
	/** Players sitting in this lobby keyed by player id. */
	public var players(default, null) : Map<String, LobbyPlayer>;

	/** peerId (local RNL id) -> playerId, populated on join. */
	var playerByPeer : Map<Int, String> = new Map();

	/** Counter to generate stable ids for auto-joined players. */
	var nextPlayerId : Int = 1;

	public function new(id : String, gd : GameData, port : Int)
	{
		super(id, "lobby", gd, port, false); // worldless: no SimWorld, no physics
		players = new Map();

		// wire lobby-specific RPC handlers on the inherited socket
		netSys.onJoin = name -> handleJoin(name);
		netSys.onSetReady = v -> handleSetReady(v);
		netSys.onAnnounce = text -> trace('LOBBY "' + id + '" announce: ' + text);
		netSys.onPeerConnect = peerId -> trace('LOBBY "' + id + '" peer connect id=' + peerId);
		netSys.onPeerDisconnect = peerId -> {
			trace('LOBBY "' + id + '" peer disconnect id=' + peerId);
			var drop = playerByPeer.get(peerId);
			if (drop != null) leave(drop);
		};

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

	/** Handle a join RPC from a client. Uses the invoking peer id (patched
		`__rpcCaller`) so a disconnect can clean up the right player. */
	function handleJoin(name : String) : Void
	{
		var peerId = netSys != null && netSys.net != null ? netSys.net.__rpcCaller : -1;
		var pid = "p" + (nextPlayerId++);
		if (peerId >= 0) playerByPeer.set(peerId, pid);
		join(pid, name);
	}

	function handleSetReady(v : Bool) : Void
	{
		// map the invoking peer to its player and toggle only that one
		var peerId = netSys != null && netSys.net != null ? netSys.net.__rpcCaller : -1;
		var pid = peerId >= 0 ? playerByPeer.get(peerId) : null;
		if (pid == null)
		{
			trace('LOBBY "' + id + '" setReady ignored: no player for peer ' + peerId);
			return;
		}
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
