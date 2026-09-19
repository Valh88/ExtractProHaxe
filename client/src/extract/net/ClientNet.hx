package extract.net;

/**
	Client-side networking (HL only, `#if sys`). General-purpose socket
	transport: connects to a server, polls the socket, tracks mirror arrival,
	and exposes a generic `findMirror<T>()` for consumers.

	Ownership: created by a presentation System (e.g. RoomNetSystem) that
	owns its lifecycle — the system calls dispose() when the scene is left. The web target has no UDP/RNL — this class is
	never compiled there.

	Usage:
		var cn = new ClientNet("Alice");
		cn.onConnected = socket -> {
			var lobby = cn.findMirror(LobbyNet);
			lobby.join("Alice");
		};
**/
#if !sys
class ClientNet
{
	/** Display name chosen for this client. */
	public var playerName(default, null) : String;

	public function new(?name : String, ?port : Int)
	{
		playerName = name != null ? name : "Client-" + Std.random(9000);
	}

	public function update(dt : Float) : Void {}
	public function dispose() : Void {}

	/** Generic mirror search — returns null on the web stub. */
	public function findMirror<T>(cls : Class<T>) : Null<T>
	{
		return null;
	}

	/** All mirrored objects of `cls` — empty array on the web stub. */
	public function findObjects<T>(cls : Class<T>) : Array<T>
	{
		return [];
	}
}
#else
import rnl.net.NetworkSerializable;
import shared.net.NetConfig;
import shared.net.NetRegistry;

import rnl.net.SocketHost;
import rnl.Address;
import rnl.Enums.ChannelType;

class ClientNet
{
	/** The single active socket host of the current scene. */
	public var socket(default, null) : Null<SocketHost>;

	/** Display name chosen for this client. */
	public var playerName(default, null) : String;

	/** Fired once when the first mirror appears (server FULLSYNC arrived).
		The callback receives the socket so the consumer can find its typed
		mirror via `findMirror<T>()`. */
	public var onConnected : Null<SocketHost -> Void> = null;

	/** Fired when the server drops the peer (remote disconnect). */
	public var onPeerDisconnect : Null<Int -> Void> = null;

	/** True once a mirror has appeared (FULLSYNC arrived). */
	public var connected(default, null) : Bool = false;

	/** True once the connect attempt timed out (server unreachable). */
	public var connectTimedOut(default, null) : Bool = false;

	/** Wall-clock timestamp of the socket creation (for the connect timeout). */
	var connectStart : Float = 0;

	/** The port this client connected to (for timeout messages). */
	var connectPort : Int = 0;

	public function new(?name : String, ?port : Int)
	{
		NetRegistry.init();
		playerName = name != null ? name : "Client-" + Std.random(9000);
		this.connectPort = port != null ? port : NetConfig.LOBBY_PORT;
		connectStart = haxe.Timer.stamp();
		socket = new SocketHost();
		socket.channelTypes = [ChannelType.ReliableOrdered, ChannelType.UnreliableOrdered];
		var addr = Address.parse(NetConfig.LOBBY_HOST);
		addr.port = this.connectPort;
		trace('CLIENT connecting to ' + NetConfig.LOBBY_HOST + ':' + this.connectPort);
		socket.connect(addr);
		socket.onPeerConnect = peerId -> trace('CLIENT peer connected id=' + peerId);
		socket.onPeerDisconnect = peerId -> {
			trace('CLIENT peer disconnected id=' + peerId);
			if (onPeerDisconnect != null) onPeerDisconnect(peerId);
		};
	}

	/** Poll the RNL socket and detect mirror arrival. */
	public function update(dt : Float) : Void
	{
		if (socket == null) return;
		socket.update(0);

		if (connectTimedOut) return;

		if (!connected)
		{
			// any NetworkSerializable mirror means the server is ready
			var objCount = Lambda.count(socket.objects);
			if (objCount == 0)
			{
				if (haxe.Timer.stamp() - connectStart > NetConfig.CONNECT_TIMEOUT_SECONDS)
				{
					connectTimedOut = true;
					trace('CLIENT connect TIMEOUT: no server at '
						+ NetConfig.LOBBY_HOST + ':' + this.connectPort
						+ ' within ' + NetConfig.CONNECT_TIMEOUT_SECONDS + 's — dropping socket');
					socket.dispose();
					socket = null;
				}
				return;
			}
			connected = true;
			trace('CLIENT connected (mirror up, ' + objCount + ' object(s))');
			if (onConnected != null) onConnected(socket);
		}
	}

	/** Find a mirrored NetworkSerializable by class in the socket's registry. */
	public function findMirror<T:NetworkSerializable>(cls : Class<T>) : Null<T>
	{
		if (socket == null) return null;
		for (o in socket.objects)
		{
			var m = Std.downcast(o, cls);
			if (m != null) return m;
		}
		return null;
	}

	/** All mirrored NetworkSerializable instances of `cls` (empty on web). */
	public function findObjects<T:NetworkSerializable>(cls : Class<T>) : Array<T>
	{
		if (socket == null) return [];
		var out : Array<T> = [];
		for (o in socket.objects)
		{
			var m = Std.downcast(o, cls);
			if (m != null) out.push(m);
		}
		return out;
	}

	public function dispose() : Void
	{
		if (socket != null)
		{
			socket.dispose();
			socket = null;
		}
		connected = false;
		connectTimedOut = false;
	}
}
#end
