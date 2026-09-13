package;

import extract.net.ClientNet;
import shared.net.GameNet;
import shared.net.HeroObject;
import shared.net.LobbyNet;

/**
	Headless demo-room test: connects to the demo room (port 1790), joins via
	the LobbyNet mirror and watches HeroObject mirrors arrive/replicate
	(server spawns one per join, SyncBridge pushes positions).

	Args: <name> <frames> <dirX>
	- dirX != 0 also sends movement input each 0.1s (heroInput dirX) so a
	  pair of clients can verify the server resolves each input to the RIGHT
	  player (Alice dirX=+1, Bob dirX=-1 -> p1 moves +X, p2 moves -X).
**/
class DemoRoomTest
{
	static function main()
	{
		var name = Sys.args().length > 0 ? Sys.args()[0] : "Tester";
		var n = Sys.args().length > 1 ? Std.parseInt(Sys.args()[1]) : 5000;
		var dirX = Sys.args().length > 2 ? Std.parseFloat(Sys.args()[2]) : 0;
		trace("== demo-room net test (" + name + ", dirX=" + dirX + ") ==");
		var net = new ClientNet(name, 1790);
		var joined = false;
		// send input ~ every 0.1s
		var act = 0;
		for (i in 0...n)
		{
			net.update(0);
			if (net.connectTimedOut) break;
			if (!joined && net.connected)
			{
				joined = true;
				var lobby = net.findMirror(LobbyNet);
				if (lobby != null) lobby.join(name);
				act = 0;
			}
			if (net.connected)
			{
				if (dirX != 0)
				{
					if (act >= 10)
					{
						act = 0;
						var gn = net.findMirror(GameNet);
						if (gn != null) gn.heroInput(dirX, 0, 1.2, 1, false);
					}
					act++;
				}
				var objs = net.findObjects(HeroObject);
				for (o in objs)
				{
					if (!seen.exists(o.playerId))
					{
						seen.set(o.playerId, true);
						trace('HEROOBJ new ' + o.playerId + ' "' + o.name + '" hp=' + o.hp + ' maxHp=' + o.maxHp);
					}
					if (i % 25 == 0)
						trace('HEROOBJ ' + o.playerId
							+ ' pos=' + Std.int(o.posX * 100) / 100 + ',' + Std.int(o.posY * 100) / 100 + ',' + Std.int(o.posZ * 100) / 100
							+ ' yaw=' + Std.int(o.yaw * 100) / 100
							+ ' hp=' + o.hp);
				}
			}
			Sys.sleep(0.01);
		}
		net.dispose();
		trace("== demo-room net test done ==");
	}

	static var seen : Map<String, Bool> = new Map();
}