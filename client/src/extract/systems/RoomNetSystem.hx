package extract.systems;

#if !sys
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/** Web stub: no UDP/RNL, so the networking system is a no-op. */
class RoomNetSystem extends System
{
	public function new(bus : EventBus, ?gd : GameData, ?port : Int) super(bus, null, gd, "RoomNet");
}
#else
import extract.net.ClientNet;
import shared.GameData;
import shared.events.EventBus;
import shared.net.LobbyNet;
import shared.net.PlayerInfo;
import shared.systems.System;

/**
	Client-side networking system (HL only via ClientNet). Owns the one active
	RNL socket for the current scene's lifetime: creates it, pumps it each
	frame, performs the one-shot join/ready handshake, and publishes roster
	updates onto the bus.

	Generic over the mirror type via ClientNet.findMirror<T>() — currently
	uses LobbyNet; extend by adding findMirror calls in onConnected for new
	net facades (GameNet, ChatNet, etc.).

	Contract: this is a client presentation system (`sim == null`) — it talks
	to the rest of the app only through the event bus. It owns and disposes
	its ClientNet, so no upper layer holds the socket.
**/
class RoomNetSystem extends System
{
	/** The owned socket transport. */
	public var clientNet(default, null) : Null<ClientNet>;

	/** Typed mirror of the server's LobbyNet (set once connected). */
	var mirror : Null<LobbyNet>;

	var joined : Bool = false;
	var readySent : Bool = false;

	public function new(bus : EventBus, ?gd : GameData, ?port : Int)
	{
		super(bus, null, gd, "RoomNet");
		clientNet = new ClientNet(null, port);
		clientNet.onConnected = onConnected;
		clientNet.onPeerDisconnect = onPeerDisconnect;
	}

	/** Called once when the server mirror appears. */
	function onConnected(socket : rnl.net.SocketHost) : Void
	{
		mirror = clientNet.findMirror(LobbyNet);
		if (mirror == null)
		{
			trace('CLIENT room: no LobbyNet mirror found');
			return;
		}
		trace('CLIENT room: connected, mirror up');
		mirror.onRoster = onRoster;
		mirror.onAnnounce = onAnnounce;
	}

	/** Called when the server drops the peer (remote disconnect). */
	function onPeerDisconnect(peerId : Int) : Void
	{
		trace('CLIENT room: peer ' + peerId + ' disconnected');
		mirror = null;
		joined = false;
		readySent = false;
	}

	override public function update(dt : Float) : Void
	{
		var c = clientNet;
		if (c == null) return;

		c.update(dt); // poll the socket, track the mirror

		if (!joined)
		{
			if (mirror == null) return;
			joined = true;
			trace('CLIENT join("' + clientNet.playerName + '")');
			mirror.join(clientNet.playerName);
		}
		else if (!readySent)
		{
			readySent = true;
			trace('CLIENT ready(true)');
			mirror.setReady(true);
		}
	}

	/** Fired by the transport when the server broadcasts a roster. */
	public function onRoster(players : Array<PlayerInfo>) : Void
	{
		trace('CLIENT roster: ' + (players == null ? 0 : players.length) + ' player(s)');
		if (players != null)
			for (p in players)
				trace('  - ' + p.id + ' "' + p.name + '" ready=' + p.ready);
	}

	/** Fired by the transport when the server broadcasts an announce. */
	public function onAnnounce(text : String) : Void
	{
		trace('CLIENT announce: ' + text);
	}

	override public function dispose() : Void
	{
		trace('CLIENT room: disposing');
		if (clientNet != null)
		{
			clientNet.dispose();
			clientNet = null;
		}
		mirror = null;
		super.dispose();
	}
}
#end
