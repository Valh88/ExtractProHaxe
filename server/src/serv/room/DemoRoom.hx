package serv.room;

import shared.GameData;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.EntityNetSpawned;
import shared.events.GameEvents.EntityNetRemoved;
import shared.replication.SyncBridge;
import shared.systems.HeroSystem;

import serv.systems.DemoLogSystem;

/**
	Concrete room using the current SimWorld gameplay unchanged (floor, auto
	cubes, hero/bullet sim systems). Demonstrates BOTH attachment points:

	- TO THE WORLD: inherited — the base SimWorld already registers the shared
	  sim systems (Hero, Bullet) inside `world`.
	- TO THE ROOM: a DemoLogSystem is added to `roomSystems` to prove that
	  server-only room logic ticks in the pool alongside the world.

	Networking (Pattern A): on every join this room allocates a server
	player id and delegates the entity lifecycle to HeroSystem (authoritative
	hero PhysBody + `HeroObject`, server-owned `@:s`). HeroSystem publishes
	EntityNetSpawned/EntityNetRemoved on the bus; the room subscribes and
	routes each net object onto its socket. The id is broadcast via
	GameNet.playerJoined. SyncBridge (true) pushes the authoritative body
	position into the HeroObject each tick. Server receives input intents
	(fireBullet/heroInput) and routes them into the room bus -> shared sim.
**/
class DemoRoom extends Room
{
	/** peerId (local RNL id) -> playerId (keys HeroObjects and hero bodies). */
	var playerByPeer : Map<Int, String> = new Map();

	public function new(id : String, gd : GameData, port : Int)
	{
		super(id, "demo", gd, port);

		// log client connections to this game room
		netSys.onPeerConnect = peerId -> trace('GAME "' + id + '" peer connected id=' + peerId);
		netSys.onPeerDisconnect = peerId -> {
			var pid = playerByPeer.get(peerId);
			trace('GAME "' + id + '" peer disconnected id=' + peerId
				+ (pid != null ? ' "' + pid + '"' : ''));
			if (pid != null) leave(peerId, pid);
		};
		netSys.onJoin = name -> {
			var peerId = netSys.net != null ? netSys.net.__rpcCaller : -1;
			if (peerId < 0)
			{
				trace('GAME "' + id + '" join ignored: no __rpcCaller');
				return;
			}
			join(peerId, name);
		};
		netSys.onSetReady = v -> {
			var peerId = netSys.net != null ? netSys.net.__rpcCaller : -1;
			trace('GAME "' + id + '" setReady=' + v + ' from peer ' + peerId);
		};

		// server receives player input -> local sim events (authoritative tick).
		// The playerId is resolved here from the RPC caller's peer id, never
		// taken from the client — a client cannot steer another player's hero.
		gameNet.onHeroInput = (dirX, dirZ, yaw, mag, jump) ->
		{
			var pid = callerPid();
			if (pid != null) bus.publish(new HeroMoveIntent(pid, dirX, dirZ, yaw, mag, jump));
		};
		gameNet.onFire = (x, y, z, dirX, dirY, dirZ) ->
		{
			var pid = callerPid();
			if (pid != null) bus.publish(new BulletFired(pid, x, y, z, dirX, dirY, dirZ));
		};

		// the ONLY copy of hero position: physics body -> HeroObject (push)
		roomSystems.add(new SyncBridge(bus, world, true, gd));

		logger = new StateLogger();
		roomSystems.add(new DemoLogSystem(bus));

		// HeroSystem owns HeroObject lifecycle; the ROOM only routes each
		// net object onto its socket — the socket is owned by netSys, never
		// by the sim. Transport subscribes to the bus events that HeroSystem
		// publishes when it creates/removes an entity.
		bus.subscribe(EntityNetSpawned, e -> {
			if (e.obj != null) netSys.socket.add(e.obj);
		});
		bus.subscribe(EntityNetRemoved, e -> {
			if (e.obj != null) netSys.socket.remove(e.obj);
		});
	}

	/** Resolve the playerId of the peer that dispatched the current @:rpc
		(the `__rpcCaller` patch sets it on the GameNet just before the RPC
		body runs). Returns null for non-peers / not-joined peers. */
	function callerPid() : Null<String>
	{
		var peerId = gameNet.__rpcCaller;
		if (peerId < 0) return null;
		return playerByPeer.get(peerId);
	}

	/** A peer is ready to play: create its authoritative HeroObject + hero body. */
	function join(peerId : Int, name : String) : Void
	{
		var pid = netSys.allocPlayerId();
		playerByPeer.set(peerId, pid);
		trace('GAME "' + id + '" join "' + name + '" from peer ' + peerId + ' -> ' + pid);

		// authoritative hero body + replicated HeroObject (server-owned, @:s)
		// are created together by HeroSystem.spawnHero — the room stays out
		// of the entity lifecycle; EntityNetSpawned on the bus routes the
		// net object onto the socket.
		var heroSys : HeroSystem = cast world.systems.get("Hero");
		if (heroSys != null) heroSys.spawnHero(pid, true, name);

		// tell every client the new player's server id (own id = name match)
		gameNet.playerJoined(pid, name);
	}

	/** Peer gone: HeroSystem releases body + state + HeroObject (-> socket.remove). */
	function leave(peerId : Int, pid : String) : Void
	{
		var heroSys : HeroSystem = cast world.systems.get("Hero");
		if (heroSys != null) heroSys.removeHero(pid);
		playerByPeer.remove(peerId);
		netSys.net.announce('playerLeft:' + pid);
		trace('GAME "' + id + '" released "' + pid + '"');
	}
}