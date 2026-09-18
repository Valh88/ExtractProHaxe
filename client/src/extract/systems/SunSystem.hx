package extract.systems;

import h3d.Vector;
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/** Client-only: the scene's sun — a directional light emulating solar rays
    (casts all hard shadows) plus a decorative glowing disc that floats out
    along the light's direction so the player can SEE the sun in the sky.

    Presentation system (sim == null): pure visuals, no physics. The disc is
    decoration only — it emits no light (engines keep the glowing ball and the
    light source separate: DirLight does all shading and shadowing). */
class SunSystem extends System
{
	/** Distance from the camera to the visible sun disc (m). */
	public static inline var SUN_DIST : Float = 300;
	/** Radius of the visible sun disc (m). */
	public static inline var SUN_RADIUS : Float = 40;

	/** The directional sun light (main light, casts shadows). */
	public var light(default, null) : h3d.scene.pbr.DirLight;
	/** The decorative sun disc — emissive, casts nothing, follows the camera. */
	public var sunMesh(default, null) : h3d.scene.Mesh;
	/** World-space center of the sun disc (shared ref for the fog exclusion). */
	public var sunPos(default, null) : h3d.Vector;

	var scene : h3d.scene.Scene;
	/** Direction FROM the camera TOWARD the sun (opposite of the light rays). */
	var sunDir : h3d.Vector;

	public function new(bus : EventBus, scene : h3d.scene.Scene,
			sunMesh : h3d.scene.Mesh, ?gd : GameData)
	{
		super(bus, null, gd, "Sun");
		this.scene = scene;

		// light rays travel toward the camera in (-0.5,-0.4,-1) — the disc
		// sits in the opposite direction, i.e. where the sun actually is
		var rays = new Vector(-0.5, -0.4, -1);
		light = new h3d.scene.pbr.DirLight(rays, scene);
		light.power = 2;
		light.isMainLight = true;
		light.shadows.mode = h3d.pass.Shadows.RenderMode.Dynamic;
		light.shadows.size = 3048;
		light.shadows.power = 150;
		light.shadows.bias *= 0.3;
		sunDir = rays.clone().normalized();
		sunDir.scale(-1);

		// the visible sun comes from the entity factory — pure decoration,
		// no light contribution, no shadows (meshForSun sets castShadows=false)
		this.sunMesh = sunMesh;
		sunMesh.setScale(SUN_RADIUS);
		scene.addChild(sunMesh);
		sunPos = new h3d.Vector();
	}

	override public function update(dt : Float)
	{
		// keep the disc pinned out in the sky: always SUN_DIST away from the
		// camera along the sun direction — moving the player never reaches it
		var cam = scene.camera;
		sunMesh.x = cam.pos.x + sunDir.x * SUN_DIST;
		sunMesh.y = cam.pos.y + sunDir.y * SUN_DIST;
		sunMesh.z = cam.pos.z + sunDir.z * SUN_DIST;
		sunPos.set(sunMesh.x, sunMesh.y, sunMesh.z);
	}
}