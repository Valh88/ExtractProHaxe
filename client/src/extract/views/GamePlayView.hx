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
//import extract.models.PlayerModel;
import extract.systems.PlayerControllerSystem;
import extract.utils.BaseScene;
import extract.utils.CursorManager;

class GamePlayView extends BaseScene
{
	var hud : HudDesign;

	var sim : SimWorld;
	var physRenderer : PhysRenderer;
	var player : PlayerControllerSystem;
	//var playerModel : PlayerModel;

	public function new(s2d : Scene2D, style : Style, gd : GameData, bus : EventBus)
	{
		super(s2d, style, gd, bus, 0x0D0D0D);
		this.renderer.effects.push(new extract.gfx.ScalableAO());
		this.renderer.effects.push(new extract.gfx.DistanceFog());

	#if hide
		// level authored in Hide's scene editor, loaded as a prefab (HL only —
		// the web target has no hide support and uses the procedural level below)
		var level = hxd.Res.load("levels/test.prefab").toPrefab();
		level.load().make(this);
		sim = new SimWorld(this.gd, bus);
	#else
		//procedural level on targets without hide (web)
		sim = new SimWorld(this.gd, bus);
	#end

		// CLIENT consumer: maps each PhysBody to a mesh and interpolates it;
		// the core is required — it drives the alpha (interpol phase) of
		// every render() call. Without it alpha=1.0: no interpolation,
		// meshes teleport between 30 Hz physics states = jitter
		physRenderer = new PhysRenderer(sim.physCore);
		sim.phys.addConsumer(physRenderer);

		// rigged hero character model (holds hero + future weapons/attachments)
		//playerModel = new PlayerModel();
		//this.addChild(playerModel);

		// when the shared logic spawns a body, the client decides how to draw it
		// camera is anchored to the hero mesh (eye position) — bind on spawn
		player = new PlayerControllerSystem(bus, camera, null, this.gd);
		systems.add(player);
		sim.onSpawn = b ->
		{
			var mesh = meshForBody(b);
			if (mesh != null)
			{
				this.addChild(mesh);
				physRenderer.bind(b, mesh);
				if (b.name == "hero")
				{
					player.mesh = mesh;
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

	#if hide
		var prefabPhys = new shared.PrefabPhysics(sim.phys);
		var statics = prefabPhys.load(shared.PrefabPhysics.defaultLevelPath("levels/test.prefab"));
		trace("PREFAB-PHYS statics=" + statics.length + " " + [for (b in statics) b.name].join(","));
	#end

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
				null;
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
		}
		m.mainPass.addShader(pbr);
		return new h3d.scene.Mesh(prim, m);
	}

	override public function update(dt : Float)
	{
		sim.update(dt);    // shared simulation (fixed Hz) — same call as the server
		physRenderer.render(); // interpolated visuals every frame
		super.update(dt);  // scene systems (debug cam, ...) + domkit sync
	}
}
