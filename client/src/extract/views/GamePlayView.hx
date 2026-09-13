package extract.views;

import h2d.Scene as Scene2D;
import h2d.domkit.Style;

import phys.core.PhysBody;
import phys.core.PhysCore;
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

	sim = new SimWorld(this.gd, bus);
		// SimWorld.buildLevel() owns the level geometry (identical client+server).
		// Visuals: hide draws the prefab meshes on HL; web falls back to the box
		// mesh meshForBody builds (default case, #else below).
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


		sim.onSpawn = b ->
		{
			var mesh = meshForBody(b);
			if (mesh != null)
			{
				this.addChild(mesh);
				physRenderer.bind(b, mesh);
				if (b.name == "hero")
			{
				// bind the camera ONLY to the LOCAL hero — remote heroes spawn
				// later and must NOT steal the view anchor (sim.hero is the
				// local body because setHero registers it before onSpawn)
				if (sim.hero == b) player.mesh = mesh;
				// make the rigged character follow the hero body
				//playerModel.hero.follow = mesh;
			}
			}
		};
		// draw the initial scene too (created before onSpawn was set)
		for (b in sim.existingBodies())
			sim.onSpawn(b);

		// client explicitly spawns the local hero — the server does this
		// only when a real client connects (with that client's id)
		var heroSys : HeroSystem = cast sim.systems.get("Hero");
		heroSys.spawnHero(Player.LOCAL);

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

	/** Build a mesh for a spawned body. Extend this switch for new entities. */
	function meshForBody(b : PhysBody) : Null<h3d.scene.Mesh>
	{
		var sizes = b.getShapeSizes();
		if (sizes == null) return null;
		var prim : h3d.prim.Primitive = switch (b.name)
		{
			case "floor":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			case "cube":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			case "hero":
				// capsule collider: hx = radius, hy = cylinder half-height; Oimo
				// capsule is Y-aligned, so build the heaps mesh on the Y axis
				var cap = new h3d.prim.Capsule(sizes.hx, sizes.hy * 2, 12, h3d.prim.Capsule.Axis.Y);
				cap.addNormals();
				cap;
			case "bullet":
				var s = new h3d.prim.Sphere(sizes.hx, 12, 8);
				s.addNormals();
				s;
			default:
				// static obstacle from the level prefab (pillars, ...): hide
				// draws the authored meshes on HL, so skip the sim box there;
				// targets without hide (web) fall back to this box.
			#if hide
				null;
			#else
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			#end
		}
		if (prim == null) return null;
		var poly = Std.downcast(prim, h3d.prim.Polygon);
		if (poly != null && poly.normals == null) poly.addNormals();
		if (poly != null) poly.addUVs();

		var m = h3d.mat.Material.create();
		var pbr = new h3d.shader.pbr.PropsValues();
		switch (b.name)
		{
			case "floor": // rough concrete
				pbr.metalnessValue = 0;
				pbr.roughnessValue = 0.9;
				m.color.set(0.6, 0.6, 0.6, 1);
			case "cube": // metal
				pbr.metalnessValue = 0.8;
				pbr.roughnessValue = 0.3;
				m.color.set(0.4, 0.6, 1, 1);
			case "hero": // warm orange hero capsule
				pbr.metalnessValue = 0.1;
				pbr.roughnessValue = 0.5;
				m.color.set(1, 0.55, 0.2, 1);
			case "bullet": // bright yellow projectile
				pbr.metalnessValue = 0.2;
				pbr.roughnessValue = 0.4;
				m.color.set(1, 0.95, 0.2, 1);
			default: // prefab obstacle (pillar, ...) — plain concrete
				pbr.metalnessValue = 0;
				pbr.roughnessValue = 0.85;
				m.color.set(0.55, 0.5, 0.45, 1);
		}
		m.mainPass.addShader(pbr);
		return new h3d.scene.Mesh(prim, m);
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
		for (o in roomNet.clientNet.findObjects(HeroObject))
		{
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
			heroSys.spawnHero(o.playerId, false); // remote: mirror puppet, no state
			trace('CLIENT remote hero spawned: ' + o.playerId);
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
		bs.spawnBullet(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
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
