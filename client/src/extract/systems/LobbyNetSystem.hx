package extract.systems;

#if !sys
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/** Web stub: no UDP/RNL, so the lobby networking system is a no-op. */
class LobbyNetSystem extends System
{
	public function new(bus : EventBus, ?gd : GameData) super(bus, null, gd, "LobbyNet");
}
#else
import extract.net.ClientNet;
import shared.GameData;
import shared.events.EventBus;
import shared.net.PlayerInfo;
import shared.systems.System;

/**
	Lobby networking presentation system (client, HL only via ClientNet).
	Owns the lobby ClientNet (the lobby's one active socket) for the lifetime
	of the lobby scene: creates it, pumps it each frame, performs the one-shot
	join/ready handshake, and publishes roster updates onto the bus.

	Contract: this is a client presentation system (`sim == null`) — it talks
	to the rest of the app only through the event bus (publishes
	`RosterChanged`). It owns and disposes its ClientNet, so no upper layer
	holds the socket.
**/
class LobbyNetSystem extends System
{
	/** The owned lobby socket transport. */
	public var clientNet(default, null) : Null<ClientNet>;

	var joined : Bool = false;
	var readySent : Bool = false;

	public function new(bus : EventBus, ?gd : GameData)
	{
		super(bus, null, gd, "LobbyNet");
		clientNet = new ClientNet();
		clientNet.onRoster = onRoster;
	}

	override public function update(dt : Float) : Void
	{
		var c = clientNet;
		if (c == null) return;

		c.update(dt); // poll the socket, track the mirror

		if (!joined)
		{
			if (!c.connected) return;
			joined = true;
			c.join();
		}
		else if (!readySent)
		{
			readySent = true;
			c.ready();
		}
	}

	/** Fired by the transport when the server broadcasts a roster. */
	public function onRoster(players : Array<PlayerInfo>) : Void
	{
		trace('CLIENT roster: ' + (players == null ? 0 : players.length) + ' player(s)');
		if (players != null)
			for (p in players)
				trace('  - ' + p.id + ' "' + p.name + '" ready=' + p.ready);
	}

	override public function dispose() : Void
	{
		if (clientNet != null)
		{
			clientNet.dispose();
			clientNet = null;
		}
		super.dispose();
	}
}
#end
