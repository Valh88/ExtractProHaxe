package extract.gfx;

import h3d.impl.RendererFX;

/** Screen-driven eye adaptation: darkens the scene (via the PBR renderer's
    exposure) while a bright source sits near the middle of the screen, i.e.
    when the player is actually looking AT it. Simulates the eye stopping down
    on a bright source.

    Standalone `RendererFX` — depends only on heaps. Point `sunPos` at the
    light source and (optionally) `sunDir` for the daytime fade; add it to
    `renderer.effects`. Self-driving: the smoothing uses the engine frame time
    (`hxd.Timer.dt`), so no external update call is required. */
class EyeAdaptation implements h3d.impl.RendererFX
{
	public var enabled = true;

	/** How far the exposure drops when the source is dead-center (in exposure
	    units — the tone mapper applies exp(exposure), so 0 = unchanged). */
	public static var STRENGTH : Float = 0.8;
	/** Smoothing rate of the adaptation (1/s); higher = snappier. */
	public static var SPEED : Float = 3.0;
	/** Screen uv radius around the center where darkening is at full strength
	    (0.12 ≈ the central ~12% of the screen height). */
	public static var CENTER : Float = 0.12;
	/** Screen uv radius around the center where darkening has fully faded out. */
	public static var CENTER_FALLOFF : Float = 0.30;
	/** Multiplier turning the source elevation (sunDir.y) into the daytime
	    fade; the trigger is zeroed as the source sinks below the horizon. */
	public static var ELEV_FADE : Float = 4.0;

	/** World-space position of the bright source (shared ref, mutated by owner). */
	public var sunPos : h3d.Vector = new h3d.Vector();
	/** Direction from the camera toward the source (shared ref); its `.y` is the
	    elevation sine used for the daytime fade. Defaults straight up. */
	public var sunDir : h3d.Vector = new h3d.Vector(0, 1, 0);
	/** When false the trigger is disabled and the adaptation eases back to 0. */
	public var triggerEnabled : Bool = true;

	var pbr : h3d.scene.pbr.Renderer;
	var baseExposure : Float = 0.0;
	var baseCaptured : Bool = false;
	var adapt : Float = 0.0;

	public function new() {}

	public function start(r : h3d.scene.Renderer)
	{
		enabled = Std.isOfType(r, h3d.scene.pbr.Renderer);
		pbr = Std.downcast(r, h3d.scene.pbr.Renderer);
		// start() runs EVERY frame (Scene.render -> startEffects), so the base
		// exposure must be captured exactly once — re-reading it would grab the
		// already-darkened value and compound down to black.
		if (pbr != null && !baseCaptured)
		{
			baseExposure = pbr.exposure;
			baseCaptured = true;
		}
	}

	public function begin(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || pbr == null)
			return;

		var cam = @:privateAccess r.ctx.camera;
		var target = 0.0;
		if (triggerEnabled)
		{
			var proj = cam.project(sunPos.x, sunPos.y, sunPos.z, 1, 1, false);
			var m = cam.m;
			// behind-camera check: pre-divide clip w
			var cw = sunPos.x * m._14 + sunPos.y * m._24 + sunPos.z * m._34 + m._44;
			if (cw > 0.001)
			{
				var dx = (proj.x - 0.5) * cam.screenRatio;
				var dy = proj.y - 0.5;
				var rr = Math.sqrt(dx * dx + dy * dy);
				var t = 1.0 - (rr - CENTER) / (CENTER_FALLOFF - CENTER);
				t = hxd.Math.clamp(t, 0.0, 1.0);
				// daytime only: fade the trigger as the source sinks below the horizon
				t *= hxd.Math.clamp(sunDir.y * ELEV_FADE, 0.0, 1.0);
				target = t;
			}
		}

		var dt = hxd.Timer.dt;
		adapt += (target - adapt) * hxd.Math.min(1.0, dt * SPEED);
		pbr.exposure = baseExposure - STRENGTH * adapt;
	}

	public function end(r : h3d.scene.Renderer, step : Step) {}

	public function dispose()
	{
		if (pbr != null) pbr.exposure = baseExposure;
	}

	public function modulate(t : Float) : RendererFX
	{
		return this;
	}

	public function transition(r1 : RendererFX, r2 : RendererFX) : RFXTransition
	{
		return null;
	}
}
