package;

import extract.net.ClientNet;
import shared.net.GameNet;
import shared.net.HeroObject;
import shared.net.LobbyNet;

/**
	Headless demo-room test: connects to the demo room (port 1790), joins via
	the LobbyNet mirror and watches HeroObject mirrors arrive/replicate
	(server spawns one per join, SyncBridge pushes positions).

	Args: <name> <frames> <dirX> <fire>
	- dirX != 0 also sends movement input each 0.1s (heroInput dirX) so a
	  pair of clients can verify the server resolves each input to the RIGHT
	  player (Alice dirX=+1, Bob dirX=-1 -> p1 moves +X, p2 moves -X).
	- fire != 0 sends fireBullet downward each 0.5s and traces the server's
	  authoritative hit verdict when it comes back (bulletHit rpc).
**/
class DemoRoomTest
{
	static function main()
	{
		var name = Sys.args().length > 0 ? Sys.args()[0] : "Tester";
		var n = Sys.args().length > 1 ? Std.parseInt(Sys.args()[1]) : 5000;
		var dirX = Sys.args().length > 2 ? Std.parseFloat(Sys.args()[2]) : 0;
		var fire = Sys.args().length > 3 ? Std.parseInt(Sys.args()[3]) : 0;
		trace("== demo-room net test (" + name + ", dirX=" + dirX + ", fire=" + fire + ") ==");
		var net = new ClientNet(name, 1790);
		var joined = false;
		// our own server-assigned pid (discovered via HeroObject name match)
		var ownPid : String = null;
		// send input ~ every 0.1s, fire ~ every 0.5s
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
				if (dirX != 0 || fire != 0)
				{
					if (act >= 10)
					{
						act = 0;
						var gn = net.findMirror(GameNet);
						if (gn != null)
						{
							if (dirX != 0) gn.heroInput(dirX, 0, 1.2, 1, false);
							if (fire == 1) // straight down at the spawn floor
								gn.fireBullet(0, 5, 0, 0, -1, 0);
							else if (fire == 2) // horizontal point-blank at the spawn point
								gn.fireBullet(0, 1, 0, 0, 0, 1);
						}
					}
					act++;
				}
				// server-authoritative hit verdict -> split by our identity:
				// shooter only ("you hit X"), victim only ("hit by X")
				var gn = net.findMirror(GameNet);
				if (gn != null && gn.onBulletHit == null)
				{
					gn.onBulletHit = (owner, victim, x, y, z) ->
					{
						trace('CLIENT HIT ' + victim + ' at ' + Std.int(x * 100) / 100 + ',' + Std.int(y * 100) / 100 + ',' + Std.int(z * 100) / 100);
						if (ownPid == null) return;
						if (owner == ownPid)
							trace('CLIENT you hit ' + victim + ' (ShooterHit)');
						if (victim == ownPid)
							trace('CLIENT hit by ' + owner + ' (VictimHit)');
					};
				}
				var objs = net.findObjects(HeroObject);
				var here : Map<String, Bool> = new Map();
				for (o in objs)
				{
					here.set(o.playerId, true);
					if (o.name == name) ownPid = o.playerId; // find our own id
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
				// a previously-seen HeroObject mirror gone == server removed it
				// (owner disconnected) — GamePlayView despawns the puppet on it.
				var gone : Array<String> = [];
				for (pid in seen.keys()) if (!here.exists(pid)) gone.push(pid);
				for (pid in gone)
				{
					seen.remove(pid);
					trace('HEROOBJ left ' + pid + ' (mirror REMOVE)');
				}
			}
			Sys.sleep(0.01);
		}
		net.dispose();
		trace("== demo-room net test done ==");
	}

	static var seen : Map<String, Bool> = new Map();
}