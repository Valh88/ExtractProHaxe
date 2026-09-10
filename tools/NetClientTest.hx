package;

import extract.net.ClientNet;

/** Headless lobby-client test: connects, joins, reads the roster, exits. */
class NetClientTest
{
	static function main()
	{
		trace("== net client test ==");
		var net = new ClientNet("TestClient");
		var joined = false;
		var readied = false;
		net.onRoster = players -> {
			trace('CLIENT roster: ' + (players == null ? 0 : players.length) + ' player(s)');
			if (players != null)
				for (p in players)
					trace('  - ' + p.id + ' "' + p.name + '" ready=' + p.ready);
		};
		// pump for ~3s so the RNL handshake, FULLSYNC mirror, join and roster reply land
		for (i in 0...1500)
		{
			net.update(0);
			if (net.connected && !joined) { joined = true; net.join(); }
			else if (net.connected && joined && !readied) { readied = true; net.ready(); }
			Sys.sleep(0.002);
		}
		net.dispose();
		trace("== net client test done ==");
	}
}
