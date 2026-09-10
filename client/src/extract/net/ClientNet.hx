package extract.net;

import shared.net.LobbyNet;
import shared.net.NetConfig;
import shared.net.NetRegistry;
import shared.net.PlayerInfo;

import rnl.net.SocketHost;
import rnl.Address;
import rnl.Enums.ChannelType;

/**
	Client-side networking (HL only, `#if sys`). Owns the ONE active RNL
	socket of the current scene (lobby socket for the lobby prototype) and
	drives `@:rpc` join/ready + roster mirroring. Console traces only.

	Ownership: created by a presentation System (e.g. LobbyNetSystem) that
	owns its lifecycle — the system calls dispose() when the scene is left.
	The web target has no UDP/RNL — this class is never compiled there.
**/
#if !sys
class ClientNet
{
	public function new() {}
	public function update(dt : Float) : Void {}
	public function dispose() : Void {}
}
#else
class ClientNet
{
	/** The single active socket host (lobby socket for the prototype). */
	public var socket(default, null) : Null<SocketHost>;

	/** Mirror of the server's shared LobbyNet (once FULLSYNC arrives). */
	var mirror : Null<LobbyNet>;

	/** Display name chosen for this client. */
	var playerName : String;

	/** Roster hook — fired when the server broadcasts a fresh roster. */
	public var onRoster : Null<Array<PlayerInfo> -> Void> = null;

	/** True once the mirror has appeared (server FULLSYNC arrived). */
	public var connected(default, null) : Bool = false;

	/** True once the connect attempt timed out (server unreachable). */
	public var connectTimedOut(default, null) : Bool = false;

	/** Wall-clock timestamp of the socket creation (for the connect timeout). */
	var connectStart : Float = 0;

	public function new(?name : String)
	{
		NetRegistry.init(); // register CLID classes before any deserialization
		playerName = name != null ? name : "Client-" + Std.random(9000);
		connectStart = haxe.Timer.stamp();
		socket = new SocketHost();
		socket.channelTypes = [ChannelType.ReliableOrdered, ChannelType.UnreliableOrdered];
		var addr = Address.parse(NetConfig.LOBBY_HOST);
		addr.port = NetConfig.LOBBY_PORT;
		trace('CLIENT connecting to ' + NetConfig.LOBBY_HOST + ':' + NetConfig.LOBBY_PORT);
		socket.connect(addr);
		socket.onPeerConnect = peerId -> trace('CLIENT peer connected id=' + peerId);
		socket.onPeerDisconnect = peerId -> trace('CLIENT peer disconnected id=' + peerId);
	}

	/** Poll the RNL socket and track the mirror's arrival. */
	public function update(dt : Float) : Void
	{
		if (socket == null) return;
		socket.update(0);

		if (connectTimedOut) return;

		if (!connected)
		{
			var m = findMirror();
			if (m == null)
			{
				// server unreachable: no FULLSYNC mirror within the timeout
				if (haxe.Timer.stamp() - connectStart > NetConfig.CONNECT_TIMEOUT_SECONDS)
				{
					connectTimedOut = true;
					trace('CLIENT connect TIMEOUT: no server at '
						+ NetConfig.LOBBY_HOST + ':' + NetConfig.LOBBY_PORT
						+ ' within ' + NetConfig.CONNECT_TIMEOUT_SECONDS + 's — dropping socket');
					socket.dispose();
					socket = null;
				}
				return;
			}
			connected = true;
			mirror = m;
			// hook the roster callback (received via @:rpc(clients) broadcast)
			m.onRoster = players -> { if (onRoster != null) onRoster(players); };
			trace('CLIENT connected to lobby (mirror up)');
		}
	}

	/** Send join(name) to the server (fires once the mirror is up). */
	public function join() : Void
	{
		if (mirror == null) return;
		trace('CLIENT join("' + playerName + '")');
		mirror.join(playerName);
	}

	/** Send ready(true) to the server. */
	public function ready() : Void
	{
		if (mirror == null) return;
		trace('CLIENT ready(true)');
		mirror.setReady(true);
	}

	/** Find the mirrored LobbyNet in the socket's object registry. */
	function findMirror() : Null<LobbyNet>
	{
		if (socket == null) return null;
		for (o in socket.objects)
		{
			var n = Std.downcast(o, LobbyNet);
			if (n != null) return n;
		}
		return null;
	}

	public function dispose() : Void
	{
		if (socket != null)
		{
			socket.dispose();
			socket = null;
		}
		mirror = null;
		connected = false;
		connectTimedOut = false;
	}
}
#end
