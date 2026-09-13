package serv.room;

import shared.GameData;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.HeroMoveIntent;
import shared.net.HeroObject;
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
	player id, creates the authoritative `HeroObject` (server-owned, `@:s`
	replicated to clients) plus the hero PhysBody, and broadcasts the id via
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

		// per-entity game state (server-owned, @:s replicated to clients)
		var obj = new HeroObject(pid);
		obj.name = name;
		obj.hp = 100;
		obj.maxHp = 100;
		// TODO: read spawn stats (hp/maxHp/weapon) from GameData instead of literals
		world.heroEnts.set(pid, obj);
		netSys.socket.add(obj);

		// authoritative hero body so SyncBridge has a PhysBody to push from
		var heroSys : HeroSystem = cast world.systems.get("Hero");
		heroSys.spawnHero(pid);

		// tell every client the new player's server id (own id = name match)
		gameNet.playerJoined(pid, name);
	}

	/** Peer gone: release its HeroObject + hero body (REMOVE flows to clients). */
	function leave(peerId : Int, pid : String) : Void
	{
		var obj = world.heroEnts.get(pid);
		if (obj != null)
		{
			world.heroEnts.remove(pid);
			netSys.socket.remove(obj);
		}
		playerByPeer.remove(peerId);
		netSys.net.announce('playerLeft:' + pid);
		trace('GAME "' + id + '" released "' + pid + '"');
	}
}