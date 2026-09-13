package serv.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.net.LobbyNet;
import shared.net.NetRegistry;
import shared.systems.System;

import rnl.net.SocketHost;
import rnl.Address;
import rnl.Enums.ChannelType;

/**
	Server-side networking system: owns the RNL socket of ONE room/lobby and
	its shared net facade. 	Mirrors the client's RoomNetSystem — the socket
	lifecycle belongs to this system, and the room releases it via
	`roomSystems.clear()` (System.dispose).

	The room registers the RPC handlers after creating this system:
	`sys.onJoin = ...` etc. — the shared LobbyNet bodies run on the server and
	delegate to these hooks (same pattern as the client facade).
**/
class NetRoomSystem extends System
{
	/** The owned socket host of this room/lobby (its own UDP socket). */
	public var socket(default, null) : Null<SocketHost>;

	/** Shared lobby RPC facade (owned by this system, mirrored to clients). */
	public var net(default, null) : Null<LobbyNet>;

	/** RPC handlers the room fills in. */
	public var onJoin : Null<String -> Void> = null;
	public var onSetReady : Null<Bool -> Void> = null;
	public var onAnnounce : Null<String -> Void> = null;
	public var onPeerConnect : Null<Int -> Void> = null;
	public var onPeerDisconnect : Null<Int -> Void> = null;

	/** Counter for auto-assigned player ids (server-side). */
	public var nextPlayerId(default, null) : Int = 1;

	/**
		Allocate the next stable server player id ("p1", "p2", ...). Used by
		rooms to key HeroObjects and hero bodies; ids stay unique per room.
	**/
	public function allocPlayerId() : String
	{
		var id = "p" + nextPlayerId;
		nextPlayerId++;
		return id;
	}

	public function new(bus : EventBus, ?gd : GameData, port : Int)
	{
		super(bus, null, gd, "Net");
		NetRegistry.init();

		socket = new SocketHost();
		socket.channelTypes = [ChannelType.ReliableOrdered, ChannelType.UnreliableOrdered];
		var addr = Address.parse("0.0.0.0");
		addr.port = port;
		socket.listen(addr);
		socket.raw.allowIncomingConnections = true;

		net = new LobbyNet();
		socket.add(net);

		net.onJoin = name -> { if (onJoin != null) onJoin(name); };
		net.onSetReady = v -> { if (onSetReady != null) onSetReady(v); };
		net.onAnnounce = text -> { if (onAnnounce != null) onAnnounce(text); };

		socket.onPeerConnect = peerId -> { if (onPeerConnect != null) onPeerConnect(peerId); };
		socket.onPeerDisconnect = peerId -> { if (onPeerDisconnect != null) onPeerDisconnect(peerId); };
	}

	override public function update(dt : Float) : Void
	{
		if (socket != null)
			socket.update(0);
	}

	/** Push the current roster to all connected clients via @:rpc(clients). */
	public function broadcastRoster(players : Array<shared.net.PlayerInfo>) : Void
	{
		if (net == null) return;
		net.rosterChanged(players);
	}

	override public function dispose() : Void
	{
		if (socket != null)
		{
			socket.dispose();
			socket = null;
		}
		net = null;
		super.dispose();
	}
}
