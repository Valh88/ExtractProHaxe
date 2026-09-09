package serv.room;

import shared.GameData;
import shared.SimWorld;
import shared.IUpdate;
import shared.events.EventBus;
import shared.systems.Systems;
import serv.events.ServerEventBus;

/**
	Server-side room (lobby / map / ...) container. Follows the client's
	architecture: a room OWNS a world (`world : SimWorld`) the same way a
	client view owns `sim`, plus a server-only logic layer (`roomSystems`),
	the mirror of a client's presentation systems (`BaseScene.systems`).

	Two attachment points for server logic:
	- TO THE WORLD  -> `world.systems.add(...)` (shared/deterministic sim systems,
	  run inside `world.update` and mirrorable to the client).
	- TO THE ROOM   -> `roomSystems.add(...)` (server-only logic: match lifecycle,
	  timeouts, future snapshots / transport draining).

	Threading contract: a room is mutated ONLY by pool tasks (see ServerHost),
	strictly sequentially — never two ticks of the same room at once.

	A room creates its OWN event bus (ServerEventBus) and hands it to the world,
	so all systems in this room share one bus (local delivery now, broadcast to
	clients later).
**/
class Room implements IUpdate
{
	/** Unique id (owned by ServerHost registry). */
	public var id(default, null) : String;

	/** Human-readable kind, e.g. "demo" / "lobby" / "map". */
	public var kind(default, null) : String;

	/** Server-side lifecycle of this room. */
	public var state(default, set) : RoomState;

	/** Connected players (empty stub for now — roster/transport come later). */
	public var roster(default, null) : Map<String, Dynamic>;

	/** The world this room drives (own SimWorld instance). */
	public var world(default, null) : SimWorld;

	/** Shared bus of this room — created here and injected into the world. */
	public var bus(default, null) : ServerEventBus;

	/** Server-only logic layer (mirror of a client view's systems). */
	public var roomSystems(default, null) : Systems;

	/** World physics logger (set by the room itself; dumped each tick). */
	public var logger : Null<StateLogger> = null;

	/** Wall-clock accumulated run time of this room. */
	public var time(default, null) : Float = 0;

	/** Number of pool ticks performed on this room. */
	public var tickCount(default, null) : Int = 0;

	public function new(id : String, kind : String, gd : GameData)
	{
		this.id = id;
		this.kind = kind;
		this.state = Waiting;
		this.roster = new Map();
		this.roomSystems = new Systems();
		// a room creates its own bus and hands it to the world -> one shared bus
		this.bus = new ServerEventBus();
		this.world = createWorld(gd, bus);
	}

	/**
		Factory hook: create the world this room drives. Default returns a plain
		SimWorld wired to `bus`. Future maps override this to return a world
		subclass (custom level/systems) without touching Room.
	**/
	public function createWorld(gd : GameData, bus : EventBus) : SimWorld
	{
		return new SimWorld(gd, bus);
	}

	/**
		Advance the room by `dt` (real elapsed time of one host round, ~1/60s).
		The world (SimWorld) drives a FIXED simulation step (Config.PHYSICS_HZ =
		30 Hz) — PhysCore has its OWN fixed-timestep accumulator, so we pass it
		the real `dt` and it steps exactly 30 times per second, matching the
		client's physics tick rate. The room controls the world's stepping.

		Order: sim systems of the world first, then the server-only room logic —
		same layering as the client's `sim.update(dt); ...; view.systems.update(dt)`.
		Room logic runs only when the world actually advanced (tickCount() > 0),
		so it stays aligned to the sim's 30 Hz cadence.
	**/
	public function tick(dt : Float) : Void
	{
		if (state == Closed) return;
		time += dt;
		tickCount++;

		var before = world.phys.tickCount();
		world.update(dt); // sim systems of the world (PhysCore fixed 30 Hz)
		if (logger != null) logger.dump(dt); // world physics log, ~once per second
		if (world.phys.tickCount() > before)
			roomSystems.update(dt); // server-only room logic, aligned to sim ticks
	}

	/** IUpdate contract — aliases tick() so rooms can be scheduled generically. */
	public function update(dt : Float) : Void
	{
		tick(dt);
	}

	/** Close the room: stops ticking and releases owned systems. */
	public function close() : Void
	{
		state = Closed;
		roomSystems.clear();
	}

	function set_state(v : RoomState) : RoomState
	{
		return state = v;
	}
}

/** Server-side lifecycle of a room. */
enum RoomState
{
	/** Lobby: waiting for players / matchmaking. */
	Waiting;
	/** Active gameplay. */
	InGame;
	/** Finished; being torn down. */
	Ended;
	/** Closed by the host; no longer ticking. */
	Closed;
}
