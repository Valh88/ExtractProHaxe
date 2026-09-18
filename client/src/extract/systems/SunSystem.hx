package extract.systems;

import extract.gfx.DistanceFog;
import extract.gfx.LensFlare;
import h3d.Vector;
import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;

/** Sun path preset. `Circle` (default) is a full great-circle orbit — the sun
    rises, peaks below zenith and sets again (night included). `Horizon` is the
    same orbit restricted to the visible arc (the sun bounces back above the
    horizon instead of going dark). `Parabola` is a simple dawn→noon→dusk sweep
    with a sine elevation, looping without a night phase. */
enum SunTrajectory
{
	Circle;
	Horizon;
	Parabola;
}

/** Client-only: the scene's sun — a directional light emulating solar rays
    (casts all hard shadows) plus a decorative glowing disc that floats out
    along the light's direction so the player can SEE the sun in the sky.

    Presentation system (sim == null): pure visuals, no physics. The disc is
    decoration only — it emits no light (engines keep the glowing ball and the
    light source separate: DirLight does all shading and shadowing).

    The sun moves along the chosen `SunTrajectory` at a constant angular speed
    set by `dayLength` (seconds for one full cycle, default 600). Both the
    disc and the DirLight follow the same animated direction so shadows/light
    always match where the sun visibly is. */
class SunSystem extends System
{
	/** Distance from the camera to the visible sun disc (m). */
	public static inline var SUN_DIST : Float = 300;
	/** Radius of the visible sun disc (m). */
	public static inline var SUN_RADIUS : Float = 25;
	/** Peak elevation of the sun above the horizon (radians). Kept well below
	    zenith so the sun never looms overhead like at the equator. */
	public static var SUN_MAX_ELEV : Float = Math.PI * 35 / 180;
	/** Full day/night cycle length in seconds (parameter of the system). */
	public static var DEFAULT_DAY_LENGTH : Float = 600;
	/** Phase: sunAngle == 0 puts the sun at its noon peak. */
	public static var START_ANGLE : Float = 0;

	/** Eye adaptation: darken the scene (via renderer exposure) while the sun
	    sits in the middle of the screen (near the crosshair), simulating the
	    eye/brain stopping down when staring at a bright source. */
	public static var ADAPT_ENABLED : Bool = true;
	/** How far the exposure drops when the sun is dead-center (in exposure
	    units — the tone mapper applies exp(exposure), so 0 = unchanged). */
	public static var ADAPT_STRENGTH : Float = 0.8;
	/** Smoothing rate of the adaptation (1/s); higher = snappier. */
	public static var ADAPT_SPEED : Float = 3.0;
	/** Screen uv radius around the center where darkening is at full strength
	    (0.12 ≈ the central ~12% of the screen height). */
	public static var ADAPT_CENTER : Float = 0.12;
	/** Screen uv radius around the center where darkening has fully faded out. */
	public static var ADAPT_CENTER_FALLOFF : Float = 0.30;

	/** The directional sun light (main light, casts shadows). */
	public var light(default, null) : h3d.scene.pbr.DirLight;
	/** The decorative sun disc — emissive, casts nothing, follows the camera. */
	public var sunMesh(default, null) : h3d.scene.Mesh;
	/** World-space center of the sun disc (shared ref for the fog exclusion). */
	public var sunPos(default, null) : h3d.Vector;
	/** Screen-space lens flare driven by this sun (owned by the system). */
	public var lensFlare(default, null) : LensFlare;
	/** Seconds for one full cycle (0..2π of `sunAngle`). */
	public var dayLength(default, null) : Float;
	/** Sun path preset. */
	public var trajectory(default, null) : SunTrajectory;
	/** Current phase of the sun orbit, 0 = noon peak, π/2 = sunrise horizon. */
	public var sunAngle(default, null) : Float;
	/** Whether `update` advances `sunAngle` (motion on/off). When off the sun
	    freezes at its current position but the disc/light still track it. */
	public var movementEnabled(default, null) : Bool;

	var scene : h3d.scene.Scene;
	/** Direction FROM the camera TOWARD the sun (opposite of the light rays). */
	var sunDir : h3d.Vector;
	// orbit basis: sunDir(a) = cos(a)*base + sin(a)*side
	var base : h3d.Vector;
	var side : h3d.Vector;

	/** Scene exposure captured at ctor, restored on dispose. */
	var baseExposure : Float = 0.0;
	/** Smoothed adaptation amount 0..1 (0 = no darkening). */
	var adapt : Float = 0.0;

	public function new(bus : EventBus, scene : h3d.scene.Scene,
			sunMesh : h3d.scene.Mesh, ?gd : GameData,
			?trajectory : SunTrajectory, ?dayLength : Float,
			?fog : DistanceFog)
	{
		super(bus, null, gd, "Sun");
		this.scene = scene;
		this.trajectory = trajectory == null ? SunTrajectory.Circle : trajectory;

		// optional cdb override "World" -> "sunCycleSeconds" when present
		this.dayLength = dayLength != null ? dayLength : DEFAULT_DAY_LENGTH;
		if (gd != null)
		{
			var l = gd.line("World");
			var v : Dynamic = l == null ? null : Reflect.field(l, "sunCycleSeconds");
			if (v != null && Std.isOfType(v, Float)) this.dayLength = v;
		}

		sunAngle = START_ANGLE;
		movementEnabled = true;
		var pbrRenderer = scene.renderer == null ? null : Std.downcast(scene.renderer, h3d.scene.pbr.Renderer);
		if (pbrRenderer != null) baseExposure = pbrRenderer.exposure;

		// orbit plane normal tilted SUN_MAX_ELEV away from vertical: the sun
		// rides a great circle whose highest point reaches exactly SUN_MAX_ELEV
		// (never overhead) and whose lowest goes below the horizon (night)
		var s = Math.sin(SUN_MAX_ELEV);
		var c = Math.cos(SUN_MAX_ELEV);
		base = new Vector(0, s, -c); // noon: sunDir(0)
		side = new Vector(1, 0, 0);  // sunrise/sunset: sunDir(±π/2)

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
		update(0);

		// the system OWNS the lens flare: registering it here means removing
		// (and disposing) this system removes the effect in the same place
		lensFlare = new LensFlare(fog);
		lensFlare.sunPos = sunPos;
		lensFlare.elevationSource = elevation;
		var renderer = scene.renderer;
		if (renderer != null) renderer.effects.push(lensFlare);
	}

	/** Turn sun motion on/off. When disabled the sun keeps its current
	    position (disc + light stay; only the angle stops advancing). */
	public function setMovement(enabled : Bool)
	{
		movementEnabled = enabled;
	}

	/** Sun elevation: sin of the angle above the horizon (negative at night).
	    Used by the lens flare to fade out when the sun sets. */
	public function elevation() : Float
	{
		return sunDir.y;
	}

	override public function dispose()
	{
		restoreExposure();
		if (lensFlare != null)
		{
			if (scene.renderer != null) scene.renderer.effects.remove(lensFlare);
			lensFlare.dispose();
			lensFlare = null;
		}
		super.dispose();
	}

	override public function update(dt : Float)
	{
		if (movementEnabled)
			sunAngle = (sunAngle + dt * (Math.PI * 2) / dayLength) % (Math.PI * 2);
		applyOrbit();
		applyEyeAdaptation(dt);
	}

	/** Put the captured base exposure back (used on dispose). */
	function restoreExposure()
	{
		var pbrRenderer = scene.renderer == null ? null : Std.downcast(scene.renderer, h3d.scene.pbr.Renderer);
		if (pbrRenderer != null) pbrRenderer.exposure = baseExposure;
	}

	/** Darken the scene while the (daytime) sun sits near the middle of the
	    screen — i.e. the player is actually looking AT it, not just in its
	    general direction. The sun is projected to screen uv; the trigger is 1
	    within ADAPT_CENTER uv of the center and fades to 0 by
	    ADAPT_CENTER_FALLOFF. Cheap (one projection per frame), no occlusion. */
	function applyEyeAdaptation(dt : Float)
	{
		var pbrRenderer = scene.renderer == null ? null : Std.downcast(scene.renderer, h3d.scene.pbr.Renderer);
		if (pbrRenderer == null) return;

		var target = 0.0;
		if (ADAPT_ENABLED && movementEnabled)
		{
			var cam = scene.camera;
			var proj = cam.project(sunPos.x, sunPos.y, sunPos.z, 1, 1, false);
			var uvx = proj.x;
			var uvy = proj.y;
			// behind-camera check: pre-divide clip w
			var m = cam.m;
			var cw = sunPos.x * m._14 + sunPos.y * m._24 + sunPos.z * m._34 + m._44;
			if (cw > 0.001)
			{
				var dx = (uvx - 0.5) * cam.screenRatio;
				var dy = uvy - 0.5;
				var r = Math.sqrt(dx * dx + dy * dy);
				var t = 1.0 - (r - ADAPT_CENTER) / (ADAPT_CENTER_FALLOFF - ADAPT_CENTER);
				t = hxd.Math.clamp(t, 0.0, 1.0);
				// daytime only: fade the trigger as the sun sinks below the horizon
				t *= hxd.Math.clamp(sunDir.y * 4.0, 0.0, 1.0);
				target = t;
			}
		}

		adapt += (target - adapt) * hxd.Math.min(1.0, dt * ADAPT_SPEED);
		pbrRenderer.exposure = baseExposure - ADAPT_STRENGTH * adapt;
	}

	/** Recompute `sunDir` from the current `sunAngle`, move the disc to
	    `cam.pos + sunDir * SUN_DIST` and aim the light at the same spot. */
	function applyOrbit()
	{
		var a = sunAngle;
		var x : Float, y : Float, z : Float;

		switch (trajectory)
		{
			case Parabola:
				// dawn->noon->dusk sweep: sine elevation over the first half,
				// azimuth sweeps π from +Z (dawn) to -Z (dusk); then the cycle
				// wraps straight back to dawn (no night phase)
				var p = a / (Math.PI * 2);
				var elev = SUN_MAX_ELEV * Math.sin(p * Math.PI);
				var ce = Math.cos(elev);
				var az = p * Math.PI;
				x = Math.sin(az) * ce;
				y = Math.sin(elev);
				z = Math.cos(az) * ce;

			case Horizon:
				// same great circle as Circle, but when the sun sinks below the
				// horizon it is mirrored back above it — it bounces along the
				// visible arc instead of setting into darkness
				var ca = Math.cos(a) * base.y + Math.sin(a) * side.y;
				var k = ca >= 0 ? 1.0 : -1.0;
				x = k * (Math.cos(a) * base.x + Math.sin(a) * side.x);
				y = Math.abs(ca);
				z = k * (Math.cos(a) * base.z + Math.sin(a) * side.z);

			default: // Circle
				var ca = Math.cos(a);
				var sa = Math.sin(a);
				x = ca * base.x + sa * side.x;
				y = ca * base.y + sa * side.y;
				z = ca * base.z + sa * side.z;
		}

		var len = Math.sqrt(x * x + y * y + z * z);
		if (len > 0)
		{
			x /= len; y /= len; z /= len;
		}
		sunDir.set(x, y, z);

		// point the light AT the same direction so shadows match the disc:
		// DirLight shader uses lightDir = -absPos.front(), so front = -sunDir
		var cam = scene.camera;
		sunMesh.x = cam.pos.x + x * SUN_DIST;
		sunMesh.y = cam.pos.y + y * SUN_DIST;
		sunMesh.z = cam.pos.z + z * SUN_DIST;
		sunPos.set(sunMesh.x, sunMesh.y, sunMesh.z);
		light.setDirection(new Vector(-x, -y, -z));
	}
}