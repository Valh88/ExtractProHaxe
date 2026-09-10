package serv.room;

import shared.GameData;
import shared.net.LobbyNet;
import shared.net.NetConfig;
import shared.net.NetRegistry;
import shared.net.PlayerInfo;

import serv.systems.LobbyStateSystem;

import rnl.net.SocketHost;
import rnl.Address;
import rnl.Enums.ChannelType;

/**
	Lobby room — the room WITHOUT a world: players just sit in a menu/ready-up
	screen, so there is no physics to step. It inherits the shared Room
	lifecycle (state, bus, roomSystems) but is created with `withWorld=false`,
	so `world` stays null and `tick` only drives the room's own logic.

	Networking (prototype): the lobby OWNS its own RNL `SocketHost` bound to
	the dedicated lobby port. `tick()` polls the socket (`socket.update(0)`) so
	the lobby keeps servicing its own UDP socket — per-room socket, as decided.
	Incoming `@:rpc` calls (join/setReady) arrive here and mutate the roster.
**/
class LobbyRoom extends Room
{
	/** Players sitting in this lobby keyed by player id. */
	public var players(default, null) : Map<String, LobbyPlayer>;

	/** The RNL socket host of THIS lobby (its own UDP socket). */
	public var socket(default, null) : Null<SocketHost>;

	/** Shared lobby RPC facade (owned by this lobby, mirrored to clients). */
	public var net(default, null) : Null<LobbyNet>;

	/** Counter to generate stable ids for auto-joined players. */
	var nextPlayerId : Int = 1;

	public function new(id : String, gd : GameData, ?port : Int)
	{
		super(id, "lobby", gd, false); // worldless: no SimWorld, no physics
		players = new Map();
		roomSystems.add(new LobbyStateSystem(bus, this));

		// --- networking (prototype) ---
		var p = port != null ? port : NetConfig.LOBBY_PORT;
		NetRegistry.init(); // register CLID classes before any deserialization
		socket = new SocketHost();
		socket.channelTypes = [ChannelType.ReliableOrdered, ChannelType.UnreliableOrdered];
		var addr = Address.parse("0.0.0.0");
		addr.port = p;
		socket.listen(addr);
		socket.raw.allowIncomingConnections = true;

		net = new LobbyNet();
		socket.add(net);

		// route incoming RPCs to the lobby logic (bodies run on the server)
		net.onJoin = name -> handleJoin(name);
		net.onSetReady = v -> handleSetReady(v);
		net.onAnnounce = text -> {
			trace('LOBBY "' + id + '" announce: ' + text);
		};

		socket.onPeerConnect = peerId -> trace('LOBBY "' + id + '" peer connect id=' + peerId);
		socket.onPeerDisconnect = peerId -> {
			trace('LOBBY "' + id + '" peer disconnect id=' + peerId);
			// prototype: drop any auto-joined player on disconnect
			var drop = playerByPeer.get(peerId);
			if (drop != null) leave(drop);
		};
	}

	/** peerId (local RNL id) -> playerId, populated on join. */
	var playerByPeer : Map<Int, String> = new Map();

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
		// if a peer sent this, remember the mapping so disconnect can clean up
		// (prototype: no peerId plumbing in the shared facade yet, so we just join)
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
		if (net == null) return;
		var arr : Array<PlayerInfo> = [];
		for (pid in players.keys())
		{
			var p = players.get(pid);
			arr.push(new PlayerInfo(p.id, p.name, p.ready));
		}
		trace('LOBBY "' + id + '" roster -> ' + arr.length + ' players');
		net.rosterChanged(arr); // @:rpc(clients) server broadcasts to every client
	}

	override public function tick(dt : Float) : Void
	{
		if (state == Closed) return;
		// poll this lobby's own socket first: route RPCs, flush replication
		if (socket != null) socket.update(0);
		super.tick(dt);
	}

	override public function close() : Void
	{
		super.close();
		if (socket != null)
		{
			socket.dispose();
			socket = null;
		}
		net = null;
	}
}
