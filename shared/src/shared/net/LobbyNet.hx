package shared.net;

import rnl.net.NetworkSerializable;
import shared.net.PlayerInfo;

/**
	Shared lobby RPC facade. One instance is `add`ed on the server (its owner)
	and mirrored to every connected client. `@:rpc(server)` methods run on the
	server; the server pushes roster updates to clients via `@:rpc(clients)`.

	The bodies of the `@:rpc` methods are the SERVER-SIDE implementations
	(the build macro renames them to `*__im` and dispatches them on the host
	that owns the object). Because this class is shared with the client, the
	server handlers delegate to hook callbacks that the server sets — the
	shared class stays free of any server/room references.

	Model classes must be resolvable BY NAME on both ends (`Type.resolveClass`),
	so keep the full package path stable and make sure the class is included in
	both builds (see hxml `--macro include` / `-D dce=no`).
**/
class LobbyNet extends NetworkSerializable
{
	/** Server handler: a player requested to join under `name`. */
	public var onJoin : Null<String -> Void> = null;

	/** Server handler: a player toggled their ready flag. */
	public var onSetReady : Null<Bool -> Void> = null;

	/** Server handler: a player broadcast an announcement. */
	public var onAnnounce : Null<String -> Void> = null;

	public function new()
	{
		super();
	}

	/** Client -> server: request to join the lobby under `name`. */
	@:rpc(server)
	public function join(name : String) : Void
	{
		if (onJoin != null) onJoin(name);
	}

	/** Client -> server: toggle the ready flag. */
	@:rpc(server)
	public function setReady(v : Bool) : Void
	{
		if (onSetReady != null) onSetReady(v);
	}

	/** Server -> clients: broadcast the updated roster (client renderers draw it). */
	@:rpc(clients)
	public function rosterChanged(players : Array<PlayerInfo>) : Void
	{
		if (onRoster != null) onRoster(players);
	}

	/** Everyone: a chat/announce broadcast. */
	@:rpc(all)
	public function announce(text : String) : Void
	{
		if (onAnnounce != null) onAnnounce(text);
	}

	/** Client-side hook: received a fresh roster snapshot. */
	public var onRoster : Null<Array<PlayerInfo> -> Void> = null;
}
