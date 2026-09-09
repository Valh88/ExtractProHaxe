package serv.room;

/**
	A player sitting in a lobby room (no world/physics). Skeleton for the
	future roster/transport: id + display name + ready flag.
**/
class LobbyPlayer
{
	/** Unique player id (future: auth/master-server id). */
	public var id(default, null) : String;

	/** Display name (from the client/master server later). */
	public var name(default, null) : String;

	/** Ready state (client sends it; the lobby accumulates until start). */
	public var ready(default, null) : Bool = false;

	public function new(id : String, ?name : String)
	{
		this.id = id;
		this.name = name != null ? name : id;
	}

	public function setReady(v : Bool) : Void
	{
		ready = v;
	}
}