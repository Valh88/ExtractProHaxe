package serv.room;

import shared.GameData;
import shared.IUpdate;
import shared.LobbyRoom;

/**
	Room registry + lifecycle. Owns the room kind -> class mapping (spawn
	factory) and the `Map<id, Room>`. Implements IUpdate so it is itself a
	pooled server component: ServerHost schedules it like rooms/services, and
	`update(dt)` is the hook for server-side room management logic (future
	matchmaking, empty-lobby cleanup, lobby -> game transitions).

	External spawn/remove/lookup calls are made on the manager thread (between
	rounds); update() runs inside a pool task like every other component.
**/
class RoomManager implements IUpdate
{
	/** All rooms keyed by id. */
	public var rooms(default, null) : Map<String, Room>;

	var gd : GameData;
	var nextRoomId : Int = 0;

	public function new(gd : GameData)
	{
		this.gd = gd;
		rooms = new Map();

		var lobby : LobbyRoom = cast spawn("lobby");
		lobby.join("player-1", "Alice");
		lobby.join("player-2", "Bob");
		lobby.setReady("player-1", true);

		spawn("demo");
	}

	/**
		Room-management logic, advanced once per host round in the pool. Empty
		hook for now — future lifecycle/matchmaking rules live here.
	**/
	public function update(dt : Float) : Void
	{
		// TODO: lobby fill detection, empty-room timeout, lobby -> game spawn
	}

	/** Look a room up by id. */
	public function get(id : String) : Null<Room>
	{
		return rooms.get(id);
	}

	/**
		Create a room by kind and register it. Kinds: `demo` (world + physics),
		`lobby` (worldless, players in a menu). Future kinds get their matching
		Room subclasses here. Manager thread only (between rounds).
	**/
	public function spawn(kind : String, ?id : String) : Null<Room>
	{
		if (id == null) id = kind + "-" + (nextRoomId++);
		if (rooms.exists(id)) return null;

		var room : Room = switch (kind)
		{
			case "demo": new DemoRoom(id, gd);
			case "lobby": new LobbyRoom(id, gd);
			default: throw 'RoomManager: unknown room kind "$kind"';
		}
		rooms.set(id, room);
		trace('SPAWN room "' + id + '" kind=' + kind);
		return room;
	}

	/** Remove and close a room. Manager thread only. */
	public function remove(id : String) : Bool
	{
		var room = rooms.get(id);
		if (room == null) return false;
		room.close();
		rooms.remove(id);
		trace('REMOVE room "' + id + '"');
		return true;
	}

	/** Snapshot of all registered rooms, insertion order preserved. */
	public function all() : Array<Room>
	{
		var out : Array<Room> = [];
		for (r in rooms) out.push(r);
		return out;
	}

	/** Snapshot of active (non-closed) rooms, insertion order preserved. */
	public function active() : Array<Room>
	{
		var out : Array<Room> = [];
		for (r in rooms)
			if (r.state != RoomState.Closed) out.push(r);
		return out;
	}

	/** Number of registered rooms. */
	public function count() : Int
	{
		return Lambda.count(rooms);
	}

	/** Close and drop every room. */
	public function clear() : Void
	{
		for (id in rooms.keys()) rooms.get(id).close();
		rooms.clear();
	}
}