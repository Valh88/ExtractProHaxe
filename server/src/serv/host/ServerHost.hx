package serv.host;

import sys.thread.FixedThreadPool;
import sys.thread.Condition;

import shared.Config;
import shared.GameData;
import shared.IUpdate;
import serv.room.RoomManager;
import serv.room.RoomState;

/**
	Global server host: owns a FixedThreadPool and schedules server-side
	components (rooms, lobbies, and any other server part) to tick inside it.

	Dispatch model — TICK ROUNDS: every ~1/60s the manager submits one
	`update(dt)` task per pooled component into the pool (like a
	parallel-for-each), waits for all to finish (barrier), then starts the
	next round.

	Every pooled component implements `shared.IUpdate` (`update(dt)`), so
	rooms AND arbitrary server parts (matchmaking, lobby managers, ...) share
	one scheduling contract:
	- rooms are managed by a dedicated RoomManager (spawn/remove/lookup),
	- other server parts via addService()/removeService() (any IUpdate).

	Guarantees:
	- Components tick in parallel across the pool's threads.
	- A single component is NEVER ticked by two tasks at once (sequential).
	- An exception inside one component's tick is caught per-component (logged,
	  component disabled/removed) and never crashes a pool worker.

	The registries are mutated only from the manager thread (between rounds);
	when networking/master-server arrive, spawn/remove/join enter through here.
**/
class ServerHost
{
	/** Room registry + lifecycle (spawn/remove/lookup). */
	public var roomManager(default, null) : RoomManager;

	/** Other pooled server parts (any IUpdate) keyed by name. */
	public var services(default, null) : Map<String, IUpdate>;

	/** Number of worker threads in the pool. */
	public var workers(default, null) : Int;

	var pool : FixedThreadPool;

	/** Round barrier: `pending` counts ticks still running in the pool; the
		manager waits on this condition until it reaches 0. */
	var round : Condition;
	var pending : Int;
	var running : Bool;

	public function new(gd : GameData, ?workers : Int)
	{
		// HashLink's Sys has no cpuCount(); default to a small fixed pool.
		this.workers = workers != null ? workers : Config.POOL_WORKERS;
		this.roomManager = new RoomManager(gd);
		this.services = new Map();
		this.pool = new FixedThreadPool(this.workers);
		this.round = new Condition();
		this.pending = 0;
		this.running = false;
		// the room manager itself is a pooled server component (IUpdate): its
		// update(dt) ticks in the pool alongside rooms/services
		services.set("roomManager", roomManager);
	}

	/** Register any other server part that should tick in the pool. */
	public function addService(name : String, s : IUpdate) : Void
	{
		services.set(name, s);
		trace('ADD service "' + name + '"');
	}

	public function removeService(name : String) : Bool
	{
		return services.remove(name);
	}

	/**
		Run tick rounds for `seconds` REAL seconds on the calling (manager)
		thread. Each round: submit one update per pooled component into the pool,
		wait on the barrier, then repeat. `dt` is the real elapsed time since the
		previous round; each world advances at its own fixed 30 Hz via PhysCore's
		internal accumulator, so the host does not need to force 60 Hz — it just
		feeds real time and exits after `seconds` of wall-clock.
	**/
	public function run(seconds : Float) : Void
	{
		running = true;
		var round = 0;
		var start = Sys.time();
		var prev = start;
		var endAt = start + seconds;
		while (running && Sys.time() < endAt)
		{
			var now = Sys.time();
			var dt = now - prev;
			prev = now;
			if (dt > 0.1) dt = 0.1; // clamp long stalls (debugger/GC)

			round++;
			var comps = components();
			if (comps.length == 0)
			{
				Sys.sleep(0.001);
				continue;
			}
			beginRound(comps.length);
			for (c in comps)
				submitTick(c.name, c.updater, dt, c.onError);
			endRound(); // barrier: wait until every component finished this tick
			if (round % 60 == 0)
				trace('ROUND ' + round + ' t=' + Math.round((now - start) * 10) / 10
					+ 's comps=' + comps.length + ' rooms=' + roomManager.active().length
					+ ' services=' + Lambda.count(services));
			Sys.sleep(0.001); // avoid hammering the manager thread when idle
		}
		shutdown();
	}

	/** Stop the run loop and tear down the pool (idempotent). */
	public function shutdown() : Void
	{
		running = false;
		if (pool.isShutdown) return;
		roomManager.clear();
		services.clear();
		pool.shutdown();
		trace("ServerHost shutdown");
	}

	// --- internals ---

	/** Snapshot of every pooled component for one round. */
	function components() : Array<{ name : String, updater : IUpdate, onError : Null<Dynamic -> Void> }>
	{
		var out : Array<{ name : String, updater : IUpdate, onError : Null<Dynamic -> Void> }> = [];
		for (r in roomManager.active())
			out.push({ name : r.id, updater : r, onError : function(_) r.state = RoomState.Closed });
		for (k in services.keys())
			out.push({ name : k, updater : services.get(k), onError : function(_) services.remove(k) });
		return out;
	}

	function submitTick(name : String, u : IUpdate, dt : Float, onError : Null<Dynamic -> Void>) : Void
	{
		if (pool.isShutdown) return;
		pool.run(function()
		{
			try
			{
				u.update(dt);
			}
			catch (e : Dynamic)
			{
				// per-component failure: log and disable it, never crash the worker
				trace('Component "' + name + '" tick error: ' + e + " — pausing");
				if (onError != null) onError(e);
			}
			// always release the round barrier, success or failure
			doneTick();
		});
	}

	function beginRound(count : Int) : Void
	{
		round.acquire();
		pending = count;
		round.release();
	}

	function doneTick() : Void
	{
		round.acquire();
		pending--;
		var last = pending == 0;
		round.release();
		if (last) round.signal(); // wake the manager once the round is complete
	}

	function endRound() : Void
	{
		// condition-variable barrier: no spin-wait, no busy CPU. wait() atomically
		// releases the lock and sleeps; the last doneTick() signals to wake us.
		round.acquire();
		while (pending > 0)
			round.wait();
		round.release();
	}
}
