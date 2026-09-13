package serv.room;

import shared.GameData;
import shared.SimWorld;
import shared.IUpdate;
import shared.events.EventBus;
import shared.net.GameNet;
import shared.systems.Systems;
import serv.events.ServerEventBus;
import serv.factory.ServerEntityFactory;
import serv.systems.NetRoomSystem;
import serv.systems.ServerTransportSystem;

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

	Every room owns a `NetRoomSystem` (its own UDP socket via `netSys`).
	Lobby-specific handlers (join/ready) are wired by the subclass.

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

	/** Game database this room plays with (shared source of truth for tunables). */
	public var gd(default, null) : GameData;

	/** Connected players (empty stub for now — roster/transport come later). */
	public var roster(default, null) : Map<String, Dynamic>;

	/** The world this room drives (own SimWorld instance); null for worldless
		rooms such as lobbies (players just sit in a menu — no physics). */
	public var world(default, null) : Null<SimWorld>;

	/** Shared bus of this room — created here and injected into the world. */
	public var bus(default, null) : ServerEventBus;

	/** Server-only logic layer (mirror of a client view's systems). */
	public var roomSystems(default, null) : Systems;

	/** The room's networking system (owns the RNL socket + net facade). */
	public var netSys(default, null) : Null<NetRoomSystem>;

	/** Game-play RPC facade (server-owned; mirrored to every connected client). */
	public var gameNet(default, null) : GameNet;

	/** World physics logger (set by the room itself; dumped each tick). */
	public var logger : Null<StateLogger> = null;

	/** Wall-clock accumulated run time of this room. */
	public var time(default, null) : Float = 0;

	/** Number of pool ticks performed on this room. */
	public var tickCount(default, null) : Int = 0;

	public function new(id : String, kind : String, gd : GameData, port : Int, ?withWorld : Bool = true)
	{
		this.id = id;
		this.kind = kind;
		this.state = Waiting;
		this.gd = gd;
		this.roster = new Map();
		this.roomSystems = new Systems();
		// a room creates its own bus and hands it to the world -> one shared bus
		this.bus = new ServerEventBus();
		// networking: every room owns a socket (its own UDP port)
		this.netSys = new NetRoomSystem(bus, gd, port);
		roomSystems.add(this.netSys);
		// game-play RPC facade (server-owned, mirrored to clients): one-shot
		// events only — continuous state lives in per-entity HeroObjects
		this.gameNet = new GameNet();
		netSys.socket.add(gameNet);
		roomSystems.add(new ServerTransportSystem(bus, gd, gameNet));
		if (withWorld)
			this.world = createWorld(gd, bus);
	}

	/**
		Factory hook: create the world this room drives. Server side materializes
		it through the headless ServerEntityFactory (shared recipes, no visuals);
		level bodies spawn right after the world exists. Future maps override
		this to return a world subclass (custom level/systems) without touching
		Room.
	**/
	public function createWorld(gd : GameData, bus : EventBus) : SimWorld
	{
		// server sim: BulletSystem runs as the authoritative hit detector
		var factory = new ServerEntityFactory();
		var w = factory.createWorld(gd, bus, true);
		w.buildLevel();
		return w;
	}

	/**
		Advance the room by `dt` (real elapsed time of one host round, ~1/60s).

		World rooms: the world (SimWorld) drives a FIXED simulation step
		(Config.PHYSICS_HZ = 30 Hz) — PhysCore has its OWN fixed-timestep
		accumulator, so we pass it the real `dt` and it steps exactly 30 times
		per second, matching the client's physics tick rate. Room logic runs
		only when the world actually advanced (tickCount() > 0), staying
		aligned to the sim's 30 Hz cadence.

		Worldless rooms (lobbies): no physics — only the server-only room
		logic ticks, once per host round.
	**/
	public function tick(dt : Float) : Void
	{
		if (state == Closed) return;
		time += dt;
		tickCount++;

		var w = world;
		if (w == null)
		{
			// worldless room: room logic ticks every host round
			roomSystems.update(dt);
			bus.flush(); // deliver RPC-published events (queued on socket poll)
			return;
		}

		var before = w.phys.tickCount();
		w.update(dt); // sim systems of the world (PhysCore fixed 30 Hz)
		if (logger != null) logger.dump(dt); // world physics log, ~once per second
		if (w.phys.tickCount() > before)
			roomSystems.update(dt); // server-only room logic, aligned to sim ticks
		bus.flush(); // deliver events queued by RPC handlers / sim systems
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
		netSys = null;
	}

	function set_state(v : RoomState) : RoomState
	{
		return state = v;
	}
}
