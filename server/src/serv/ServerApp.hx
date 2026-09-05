package serv;

import phys.core.IPhysicsConsumer;
import phys.core.PhysBody;
import phys.core.PhysJoint;

import shared.Config;
import shared.GameData;
import shared.SimWorld;
import shared.events.GameEvents.SearchStarted;
import serv.events.ServerEventBus;

/**
	Headless server entry point: the SAME SimWorld as the client, but instead
	of rendering it logs state. No Heaps, no h3d — this build never sets
	`-D heapsphysics_render` and never links `-lib heaps`.
**/
class ServerApp
{

	public static function main()
	{
		trace("== template server (headless) ==");

		// same cdb as the client (path relative to the CWD the server runs from);
		// missing file -> Config defaults, never a crash
		var gd : GameData;
		try
		{
			gd = GameData.fromCdb(sys.io.File.getContent("client/res/db/data.cdb"));
		}
		catch (e : Dynamic)
		{
			trace("CDB not found (" + e + ") — using Config defaults");
			gd = new GameData();
		}
		trace("GAMEDATA floorHalf=" + gd.floorHalf + " cubeSize=" + gd.cubeSize
			+ " spawn=" + gd.cubeSpawnInterval + " gravity=" + gd.gravityY
			+ " heroR=" + gd.heroRadius + " heroHH=" + gd.heroHalfHeight);

		var sim = new SimWorld(gd);

		// SERVER event bus (local delivery on flush, transport in subclass)
		var bus = new ServerEventBus();
		bus.subscribe(SearchStarted, function(e : SearchStarted)
		{
			trace("SEARCH mode=" + e.mode + " (from client)");
		});

		// SERVER consumer: same interface as the client's renderer
		var logger = new StateLogger();
		sim.phys.addConsumer(logger);

		sim.onSpawn = b -> trace("SPAWN " + b.name);

		var dt = 1 / 60.0;
		var t = 0.0;
		while (t < Config.SERVER_RUN_SECONDS)
		{
			sim.update(dt); // identical call to the client's
			bus.flush();    // dispatch queued events at end of tick
			logger.dump();
			Sys.sleep(dt);
			t += dt;
		}
		trace("== done ==");
	}
}

/**
	Logs every body's last known position (like example/server ConsoleConsumer).
**/
class StateLogger implements IPhysicsConsumer
{

	var last : Map<String, String>;
	var frame : Int;

	public function new()
	{
		last = new Map();
		frame = 0;
	}

	public function onBodyAdded(b : PhysBody) : Void {}

	public function onBodyUpdated(b : PhysBody) : Void
	{
		var p = b.getPosition();
		last.set(b.name, fmt(p.x) + "," + fmt(p.y) + "," + fmt(p.z));
	}

	public function onBodyRemoved(b : PhysBody) : Void
	{
		last.remove(b.name);
	}

	public function onJointBroken(j : PhysJoint) : Void
	{
		trace("JOINT BROKEN " + j);
	}

	public function onPhysicsUpdate() : Void {}

	public function dump() : Void
	{
		if (frame++ % 30 != 0) return; // ~once per second
		for (k in last.keys())
			trace(k + " -> " + last.get(k));
	}

	public static function fmt(v : Float) : String
	{
		return (Math.round(v * 100) / 100) + "";
	}
}
