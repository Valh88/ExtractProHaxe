package serv.room;

import shared.GameData;
import serv.systems.DemoLogSystem;

/**
	Concrete room using the current SimWorld gameplay unchanged (floor, auto
	cubes, hero/bullet sim systems). Demonstrates BOTH attachment points:

	- TO THE WORLD: inherited — the base SimWorld already registers the shared
	  sim systems (Hero, Bullet) inside `world`.
	- TO THE ROOM: a DemoLogSystem is added to `roomSystems` to prove that
	  server-only room logic ticks in the pool alongside the world.

	Networking: tracks connected peers and broadcasts playerLeft via
	LobbyNet.announce() to all clients when a peer disconnects.
**/
class DemoRoom extends Room
{
	/** Peer tracking: peerId → playerName (populated on join). */
	var peerNames : Map<Int, String> = new Map();

	public function new(id : String, gd : GameData, port : Int)
	{
		super(id, "demo", gd, port);

		// log client connections to this game room
		netSys.onPeerConnect = peerId -> trace('GAME "' + id + '" peer connected id=' + peerId);
		netSys.onPeerDisconnect = peerId -> {
			var name = peerNames.get(peerId);
			trace('GAME "' + id + '" peer disconnected id=' + peerId
				+ (name != null ? ' "' + name + '"' : ''));
			// broadcast to remaining clients via LobbyNet (already on the socket)
			if (name != null)
			{
				peerNames.remove(peerId);
				netSys.net.announce('playerLeft:' + name);
				trace('GAME "' + id + '" broadcast playerLeft "' + name + '"');
			}
		};
		netSys.onJoin = name -> {
			var peerId = netSys.net != null ? netSys.net.__rpcCaller : -1;
			if (peerId >= 0) peerNames.set(peerId, name);
			trace('GAME "' + id + '" join "' + name + '" from peer ' + peerId);
		};
		netSys.onSetReady = v -> {
			var peerId = netSys.net != null ? netSys.net.__rpcCaller : -1;
			trace('GAME "' + id + '" setReady=' + v + ' from peer ' + peerId);
		};

		logger = new StateLogger();
		roomSystems.add(new DemoLogSystem(bus));
	}
}
