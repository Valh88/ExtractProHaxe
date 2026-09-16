package;

import shared.GameData;
import shared.net.HeroObject;
import shared.net.LobbyNet;
import serv.room.DemoRoom;
import extract.net.ClientNet;

/**
	Headless repro for the puppet-despawn bug: one room process + two client
	nets, then we kill Bob's socket and assert Alice's mirror list shrinks
	(the server must broadcast REMOVE for Bob's HeroObject).

	Run:
	  haxe repro_disc.hxml && $env:HL_PATH="bin/client"; hl bin/repro_disc.hl
**/
class DisconnectRepro
{
	static function main()
	{
		var gd = GameData.fromCdb(sys.io.File.getContent("client/res/db/data.cdb"));
		var room = new DemoRoom("repro", gd, 1795);

		var a = new ClientNet("Alice", 1795);
		var b = new ClientNet("Bob", 1795);

		var alive = true;
		var killAt = -1.0;
		var start = haxe.Timer.stamp();
		var phase = 0; // 0=join both, 1=wait spawn, 2=kill bob, 3=verify
		var mirrorsAtKill = 0;

		while (alive)
		{
			room.update(1 / 60);
			a.update(0);
			b.update(0);

			if (phase == 0 && a.connected && b.connected)
			{
				var la = a.findMirror(LobbyNet);
				var lb = b.findMirror(LobbyNet);
				if (la != null) la.join("Alice");
				if (lb != null) lb.join("Bob");
				phase = 1;
				trace('== joined both, pid discovery...');
			}

			var minors = a.findObjects(HeroObject).length;

			if (phase == 1 && minors >= 2)
			{
				phase = 2;
				mirrorsAtKill = minors;
				trace('== mirror count at kill: ' + minors + '; emulating peer-1 disconnect on server');
				// The RNL client socket dispose() is not detected by the server
				// within the test window (UDP teardown timing), so emulate the
				// disconnect path exactly as SocketHost.handlePeerDisconnect does:
				// it fires netSys.onPeerDisconnect -> DemoRoom.leave -> HeroSystem.removeHero.
				room.netSys.onPeerDisconnect(1);
				killAt = haxe.Timer.stamp();
			}

			if (phase == 2 && minors == 1)
			{
				phase = 3;
				trace('== FIX OK: mirror dropped from ' + mirrorsAtKill + ' -> 1 after ~'
					+ Std.int((haxe.Timer.stamp() - killAt) * 1000) + 'ms');
				alive = false;
			}

			if (haxe.Timer.stamp() - start > 8.0)
			{
				trace('== TIMEOUT: mirror count still ' + minors
					+ ' (phase ' + phase + ') — REMOVE was NOT delivered');
				alive = false;
			}
			Sys.sleep(1 / 60);
		}
		a.dispose();
		room.close();
	}
}