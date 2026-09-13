package extract.views;

import h2d.Scene as Scene2D;
import h2d.domkit.Style;

import phys.render.PhysRenderer;

import shared.SimWorld;
import shared.GameData;
import shared.Player;
import shared.events.EventBus;
import shared.systems.HeroSystem;
import extract.design.HudDesign;
import extract.models.PlayerModel;
import extract.systems.PlayerControllerSystem;
import extract.systems.RoomNetSystem;

import extract.utils.BaseScene;
import extract.utils.CursorManager;

#if sys
import extract.systems.ClientTransportSystem;
import shared.events.GameEvents.BulletHit;
import shared.events.GameEvents.BulletSpawned;
import shared.events.GameEvents.PlayerDamaged;
import shared.events.GameEvents.PlayerJoined;
import shared.events.GameEvents.ShooterHit;
import shared.events.GameEvents.VictimHit;
import shared.net.HeroObject;
import shared.replication.SyncBridge;
import shared.systems.BulletSystem;
#end

class GamePlayView extends BaseScene
{
	var hud : HudDesign;

	var sim : SimWorld;
	var physRenderer : PhysRenderer;
	var player : PlayerControllerSystem;
	var playerModel : PlayerModel;
	/** This side's entity factory — owns the world + binds meshes. */
	var factory : extract.factory.ClientEntityFactory;

#if sys
	var roomNet : RoomNetSystem;
	var clientTransport : ClientTransportSystem;
	var syncBridge : SyncBridge;
	var transportWired : Bool = false;
	/** This client's server-assigned player id (discovered by name match). */
	var ownPid : Null<String> = null;
#end

	public function new(s2d : Scene2D, style : Style, gd : GameData, bus : EventBus)
	{
		super(s2d, style, gd, bus, 0x0D0D0D);
		this.renderer.effects.push(new extract.gfx.ScalableAO());
		this.renderer.effects.push(new extract.gfx.DistanceFog());

		// entity factory owns the world: creates it (client side: meshes),
		// keeps it, spawns every body through the shared recipes
		factory = new extract.factory.ClientEntityFactory(this);
		sim = factory.createWorld(this.gd, bus, false);

		// level meshes are bound by the factory's onBodyAdded (meshForBody) —
		// the renderer must exist before the level spawns, hence buildLevel is
		// called here. Visuals: hide draws the prefab meshes on HL; web falls
		// back to the box mesh meshForBody builds (default case, #else below).
	#if hide
		var level = hxd.Res.load("levels/test.prefab").toPrefab();
		level.load().make(this);
	#end

		// CLIENT consumer: maps each PhysBody to a mesh and interpolates it;
		// the core is required — it drives the alpha (interpol phase) of
		// every render() call. Without it alpha=1.0: no interpolation,
		// meshes teleport between 30 Hz physics states = jitter
		physRenderer = new PhysRenderer(sim.physCore);
		sim.phys.addConsumer(physRenderer);
		factory.bindRenderer(physRenderer);
		sim.buildLevel();

		// rigged hero character model (holds hero + future weapons/attachments)
		playerModel = new PlayerModel();
		this.addChild(playerModel);

		// when the shared logic spawns a body, the client decides how to draw it
		// camera is anchored to the hero mesh (eye position) — bind on spawn
		player = new PlayerControllerSystem(bus, camera, null, this.gd);
		systems.add(player);

		// game-play networking stub (HL only; port = demo room's port on the server)
	#if sys
		roomNet = new RoomNetSystem(bus, gd, 1790);
		systems.add(roomNet);
		// server-broadcast events arrive on the local bus (RoomNetSystem
		// relays the GameNet mirror rpcs there) — subscribe, like any system
		bus.subscribe(PlayerJoined, onPlayerJoined);
		bus.subscribe(BulletSpawned, onBulletSpawn);
		bus.subscribe(BulletHit, onBulletHit);
		bus.subscribe(ShooterHit, onShooterHit);
		bus.subscribe(VictimHit, onVictimHit);
		bus.subscribe(PlayerDamaged, onDamage);
	#else
		systems.add(new RoomNetSystem(bus, gd, 1790));
	#end


		// client explicitly spawns the local hero — the server does this
		// only when a real client connects (with that client's id);
		// its mesh (bound by the factory) is the camera anchor
		var heroSys : HeroSystem = cast sim.systems.get("Hero");
		if (heroSys != null)
		{
			heroSys.spawnHero(Player.LOCAL);
			if (factory.localHeroMesh != null) player.mesh = factory.localHeroMesh;
		}

		// HUD on top of the gameplay scene
		hud = new HudDesign();
		s2d.addChild(hud);
		style.addObject(hud);
		style.sync();

		// hide cursor for FPS — future views (lobby/inventory) will call show()
		CursorManager.get().hide();

		// fly camera: WASD move, Q/E down/up, Shift fast, RMB drag to look
		//systems.add(new DebugCameraSystem(bus, camera, 12)); // disabled: camera belongs to the hero now
	}

	override public function update(dt : Float)
	{
	#if sys
		updateNet();
	#end
		sim.update(dt);    // shared simulation (fixed Hz) — same call as the server
		physRenderer.render(); // interpolated visuals every frame
		super.update(dt);  // scene systems (debug cam, ...) + domkit sync
	}

#if sys
	/** Wire the transport/sync once the GameNet mirror is up; poll HeroObject
		mirrors and spawn their bodies (remote heroes) as they arrive. */
	function updateNet() : Void
	{
		if (roomNet == null || roomNet.clientNet == null) return;

		var gn = roomNet.gameNet;
		if (gn != null && !transportWired)
		{
			transportWired = true;
			clientTransport = new ClientTransportSystem(bus, gd, gn);
			systems.add(clientTransport);
			syncBridge = new SyncBridge(bus, sim, false, gd);
			systems.add(syncBridge);
			trace('CLIENT transport wired');
		}

		// own-pid discovery: the HeroObject carries its OWNER's display name,
		// so at ADD time each client can tell that object of its own apart
		// from remotes — no playerJoined race, no wrongly-spawned own body.
		var myName = roomNet.clientNet.playerName;
		var mirrors = roomNet.clientNet.findObjects(HeroObject);
		var present : Map<String, Bool> = new Map();
		for (o in mirrors)
		{
			present.set(o.playerId, true);
			if (ownPid == null && o.name != null && o.name != "" && o.name == myName)
			{
				ownPid = o.playerId;
				if (syncBridge != null) syncBridge.ownId = ownPid;
				trace('CLIENT this is me: ' + ownPid);
			}
			// keep the mirror ref for ALL heroes — the own one included, so SyncBridge
			// can RECONCILE prediction against the authority.
			sim.heroEnts.set(o.playerId, o);
			if (o.playerId == ownPid) continue; // own hero: local prediction
			if (sim.heroes.exists(o.playerId)) continue; // puppet already spawned
			var heroSys : HeroSystem = cast sim.systems.get("Hero");
			if (heroSys != null) heroSys.spawnHero(o.playerId, false); // remote: mirror puppet, no state
			trace('CLIENT remote hero spawned: ' + o.playerId);
		}

		// server removed the HeroObject (owner disconnected) -> the mirror is
		// gone; release the local puppet body+mesh for every hero we spawned.
		var heroSys : HeroSystem = cast sim.systems.get("Hero");
		var pids : Array<String> = [];
		for (pid in sim.heroes.keys()) pids.push(pid);
		for (pid in pids)
		{
			if (pid == Player.LOCAL || pid == ownPid) continue; // own hero stays
			if (present.exists(pid)) continue;
			sim.heroEnts.remove(pid);
			if (heroSys != null) heroSys.removeHero(pid);
			trace('CLIENT remote hero left: ' + pid);
		}
	}

	/** Server told us a player joined this room (informational — the own id
		comes from HeroObject.name, see updateNet). */
	function onPlayerJoined(e : PlayerJoined) : Void
	{
		trace('CLIENT playerJoined ' + e.playerId + ' "' + e.name + '"');
	}

	/** Server damage feedback (instant UI); authoritative HP arrives via @:s. */
	function onDamage(e : PlayerDamaged) : Void
	{
		// TODO: HUD damage number / flash
		trace('CLIENT damage ' + e.playerId + ' : ' + e.amount);
	}

	/** Server-authoritative hit verdict — log it, drop the local bullet
		(fallback: deterministic local swept detection usually removed it
		already; this guarantees it vanishes even if a sim lagged a frame),
		and split into player-targeted events: the SHOOTER learns it hit,
		the VICTIM learns who hit them. */
	function onBulletHit(e : BulletHit) : Void
	{
		trace('CLIENT HIT ' + e.victimId + ' at '
			+ Math.round(e.x * 100) / 100 + ','
			+ Math.round(e.y * 100) / 100 + ','
			+ Math.round(e.z * 100) / 100);
		var bs : BulletSystem = cast sim.systems.get("Bullet");
		if (bs != null) bs.removeBulletByHit(e.ownerId, e.x, e.y, e.z);
		if (ownPid == null) return;
		if (e.ownerId == ownPid)
			bus.publish(new ShooterHit(e.ownerId, e.victimId, e.x, e.y, e.z));
		if (e.victimId == ownPid)
			bus.publish(new VictimHit(e.ownerId, e.victimId, e.x, e.y, e.z));
	}

	/** Local hit-confirm: my shot landed (crosshair / audio feedback hook). */
	function onShooterHit(e : ShooterHit) : Void
	{
		trace('CLIENT you hit ' + e.victimId + ' at '
			+ Math.round(e.x * 100) / 100 + ','
			+ Math.round(e.y * 100) / 100 + ','
			+ Math.round(e.z * 100) / 100);
	}

	/** Local "I was hit": show the attacker / hurt overlay hook. */
	function onVictimHit(e : VictimHit) : Void
	{
		trace('CLIENT hit by ' + e.shooterId + ' at '
			+ Math.round(e.x * 100) / 100 + ','
			+ Math.round(e.y * 100) / 100 + ','
			+ Math.round(e.z * 100) / 100);
	}

	/** Remote bullet spawn — spawn deterministically, skip own shots (already
		spawned locally); direct call (not the bus) to avoid echoing the RPC. */
	function onBulletSpawn(e : BulletSpawned) : Void
	{
		if (e.ownerId == ownPid) return;
		var bs : BulletSystem = cast sim.systems.get("Bullet");
		if (bs != null) bs.spawnBullet(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
	}

	/** Release bus subscriptions before the systems/socket are torn down. */
	override public function dispose() : Void
	{
		bus.unsubscribe(PlayerJoined, onPlayerJoined);
		bus.unsubscribe(BulletSpawned, onBulletSpawn);
		bus.unsubscribe(BulletHit, onBulletHit);
		bus.unsubscribe(ShooterHit, onShooterHit);
		bus.unsubscribe(VictimHit, onVictimHit);
		bus.unsubscribe(PlayerDamaged, onDamage);
		super.dispose();
	}
#end
}
