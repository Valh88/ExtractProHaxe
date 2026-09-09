package serv;

import shared.Config;
import shared.GameData;
import serv.host.ServerHost;
import serv.room.LobbyRoom;
import serv.room.Room;

/**
	Headless server entry point: bootstraps the global room host (ServerHost),
	spawns rooms, and runs them in a thread pool. No Heaps, no h3d — this
	build never sets `-D heapsphysics_render` and never links `-lib heaps`.
**/
class ServerApp
{

	public static function main()
	{
		trace("== template server (headless) ==");

		// same cdb as the client (path relative to the CWD the server runs from);
		// the base is the single source of truth — a missing/broken file is fatal
		var gd = GameData.fromCdb(sys.io.File.getContent("client/res/db/data.cdb"));
		trace("GAMEDATA db=" + (gd.db != null ? "loaded" : "null")
			+ " heroR=" + gd.req("Hero", "heroRadius")
			+ " heroHH=" + gd.req("Hero", "heroHalfHeight"));

		// global room manager: spawn rooms, they tick in a thread pool
		var host = new ServerHost(gd);

		// stub without networking: one demo room (current SimWorld gameplay).
		// The demo room attaches its own world physics logger internally.
		host.roomManager.spawn("demo");

		// worldless lobby room (players in a menu) — join/ready skeleton.
		// Later the network/master server would drive these calls.
		var lobby : LobbyRoom = cast host.roomManager.spawn("lobby");
		lobby.join("player-1", "Alice");
		lobby.join("player-2", "Bob");
		lobby.setReady("player-1", true);

		// pump tick rounds in the pool for the configured runtime, then exit
		host.run(Config.SERVER_RUN_SECONDS);
		trace("== done ==");
	}
}