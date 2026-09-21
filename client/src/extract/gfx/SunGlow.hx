package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA16F;

/** Screen-space sky glow («зарево») for sunrise and sunset.

    A single full-screen additive pass that paints a wide warm halo around the
    projected sun and a horizontal band of the same color right where the
    horizon meets the sun's azimuth. Both are sky-only by default: the pass
    reconstructs the world position from the depth buffer and only glows
    beyond the level's edge (sky), so geometry/terrain is never washed by it.

    Driven ONLY by the sun's live position/elevation (two shared refs) — there
    is no own time logic and no sunrise/sunset distinction: the envelope is
    symmetric around the horizon, peaking exactly at elevation 0 and fading
    out both into the day and into the night. One formula serves both phases.

    Runs BEFORE tonemapping (same step as {@link DistanceFog}/{@link LensFlare}),
    and copies its result ADDITIVELY onto the hdr — so it stacks on top of the
    already-fogged, already-flared frame instead of replacing it (register it
    AFTER the lens flare in `renderer.effects`).

    The future terrain-lighting mode is gated by {@link LIT_SURFACES}: when
    flipped on, the glow applies to the whole frame (sky + surfaces) instead
    of just the sky. Reserved — currently false (sky-only). */
class SunGlowShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		/** Input frame (fogged hdr) — sampled only for tone reference. */
		@param var sceneColor : Sampler2D;
		@param var depthTexture : Sampler2D;
		@param var inverseViewProj : Mat4;
		@param var cameraPos : Vec3;
		/** Projected sun center in texture uv (0..1, y up). */
		@param var sunUV : Vec2;
		/** 1 when the sun is in front of the camera, else 0. */
		@param var sunValid : Float;
		/** Screen uv y of the horizon at the sun's azimuth (0..1, y up). */
		@param var horizonY : Float;
		/** Screen uv x where the sun's azimuth crosses the horizon. */
		@param var horizonX : Float;
		/** 1 when that azimuth point is in front of the camera, else 0. */
		@param var horizonValid : Float;
		/** Sun elevation (sin of the angle above the horizon, -1..1). */
		@param var elev : Float;
		/** Elevation width of the horizon band (soft, ±this around 0). */
		@param var maxElev : Float;
		/** Glow color (tint; warm by default, but an editable static). */
		@param var glowColor : Vec3;
		/** Master glow strength (envelope-scaled on the CPU). */
		@param var inten : Float;
		/** Screen width/height — keeps the halo circular. */
		@param var aspect : Float;
		/** Halo radius in screen-height units. */
		@param var haloRadius : Float;
		/** Horizon band vertical half-height in texture uv. */
		@param var bandHeight : Float;
		/** Horizon band horizontal half-width in texture uv. */
		@param var bandWidth : Float;
		/** Distance (m) where "sky" starts for the depth mask. */
		@param var skyMinDist : Float;
		/** Distance (m) at which the depth mask is fully "sky". */
		@param var skyMaxDist : Float;
		/** 1 = glow all surfaces too (reserved future terrain lighting),
		    0 = sky-only (default). */
		@param var litSurfaces : Float;

		/** Soft radial lamp: 1 at `center`, 0 at `radius` (radius in
		    screen-height units; aspect-corrected). */
		function lamp(uv : Vec2, center : Vec2, radius : Float, falloff : Float) : Float {
			var d = (uv - center) * vec2(aspect, 1.0);
			return pow(max(1.0 - length(d) / radius, 0.0), falloff);
		}

		/** Vertical/horizontal gaussian-ish band falloff via smoothstep. */
		function band(offset : Float, halfWidth : Float) : Float {
			var t = abs(offset) / max(halfWidth, 0.0001);
			return 1.0 - smoothstep(0.0, 1.0, t);
		}

		function fragment() {
			var uv = calculatedUV;

			// sky mask: reconstruct world position from the depth buffer; pixels
			// beyond the level edge (sky) get 1, geometry stays 0 — unless the
			// future surface-lighting flag is on (then everything glows).
			var dt = depthTexture.get(uv).r;
			var temp = vec4(uvToScreen(uv), dt, 1.0) * inverseViewProj;
			var wp = temp.xyz / temp.w;
			var dist = distance(wp, cameraPos);
			var sky = smoothstep(skyMinDist, skyMaxDist, dist);
			var gate = mix(sky, 1.0, litSurfaces);

			// elevation envelope: peak right at the horizon, fade both into
			// the day and the night — one formula for sunrise AND sunset
			var env = 1.0 - smoothstep(0.0, maxElev, abs(elev));

			// the halo around the projected sun (wide, soft — reads as зарево)
			var halo = sunValid * lamp(uv, sunUV, haloRadius, 5.0);
			// the horizon band: hugs the horizon line, strongest on the side
			// of the sun's azimuth, fading sideways and downwards
			var bandF = horizonValid * band(uv.y - horizonY, bandHeight)
				* band(uv.x - horizonX, bandWidth);

			var glow = glowColor * inten * env * gate
				* (halo + bandF * 2.0);

			// additive copy is done by the class "end" — here we output purely
			// the glow contribution, the Copy pass adds it onto the frame.
			pixelColor = vec4(glow, 1.0);
		}
	}
}

/** Sky glow («зарево») at sunrise/sunset — see the shader class docs above. */
class SunGlow implements h3d.impl.RendererFX
{
	public var enabled = true;

	/** Master strength of the whole glow. */
	public static var INTENSITY : Float = 1.0;
	/** Radial extent of the halo around the sun, in screen-height units. */
	public static var HALO_RADIUS : Float = 0.35;
	/** Vertical half-height of the horizon band in texture uv. */
	public static var BAND_HEIGHT : Float = 0.05;
	/** Horizontal half-width of the horizon band in texture uv. */
	public static var BAND_WIDTH : Float = 0.45;
	/** Elevation (sunDir.y) range over which the glow fades from its peak at
	    the horizon (elev = 0) to nothing. ±0.15 ≈ ±8.6° — enough for the
	    colorful part of sunrise/sunset, gone in deep day/night. */
	public static var MAX_ELEV : Float = 0.15;
	/** Glow tint (warm red by default; set any color, e.g. 0xB08050 for the
	    original orange, 0xFF2E18 for a hotter red, 0xFFAA55 for a paler dawn). */
	public static var GLOW_COLOR : Int = 0xFF2E18;
	/** Distance (m) from the camera at which the depth mask starts treating
	    a pixel as sky. The demo level is 200×200 (world floorHalf=100), so
	    anything beyond ~220 is sky; keep just past the farthest geometry. */
	public static var SKY_MIN_DIST : Float = 220.0;
	/** Distance (m) at which the depth mask is fully sky. */
	public static var SKY_MAX_DIST : Float = 260.0;
	/** Reserved future feature: 1.0 lights surfaces too (whole-frame glow),
	    0.0 sky-only (default). Wired through as a shader param so enabling
	    it later needs no structural change. */
	public static var LIT_SURFACES : Bool = false;

	/** World-space sun position (shared ref, mutated each frame by SunSystem). */
	public var sunPos : h3d.Vector = new h3d.Vector();
	/** Sun elevation (sin of angle above horizon) — for the horizon envelope. */
	public var elevationSource : Null<Void -> Float> = null;

	var fx : h3d.pass.ScreenFx<SunGlowShader>;
	var glowTarget : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;

	public function new()
	{
		fx = new h3d.pass.ScreenFx(new SunGlowShader());
		fx.shader.glowColor.setColor(GLOW_COLOR);
	}

	public function start(r : h3d.scene.Renderer)
	{
		enabled = Std.isOfType(r, h3d.scene.pbr.Renderer);
		pbr = Std.downcast(r, h3d.scene.pbr.Renderer);
	}

	public function begin(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || pbr == null)
			return;
		var ctx = @:privateAccess r.ctx;
		var w = ctx.engine.width;
		var h = ctx.engine.height;
		if (glowTarget == null || glowTarget.width != w || glowTarget.height != h)
		{
			if (glowTarget != null) glowTarget.dispose();
			glowTarget = ctx.textures.allocTarget("sunglow", w, h, false, RGBA16F);
		}

		var cam = ctx.camera;
		var m = cam.m;

		// project the sun disc center into texture uv (y down, matches uv)
		var cw = sunPos.x * m._14 + sunPos.y * m._24 + sunPos.z * m._34 + m._44;
		var proj = cam.project(sunPos.x, sunPos.y, sunPos.z, 1, 1, false);
		var uvx = proj.x;
		var uvy = proj.y;

		// the horizon point at the sun's azimuth: a far point at camera eye
		// height along the sun's horizontal direction. Its projection gives
		// the horizon line's uv y + the azimuth's uv x in one shot.
		var p = cam.pos;
		var hx = sunPos.x - p.x, hz = sunPos.z - p.z;
		var hl = Math.sqrt(hx * hx + hz * hz);
		var hcw = 0.0, hux = uvx, huy = uvy;
		if (hl > 0.001)
		{
			var far = 2000.0;
			var fpx = p.x + hx / hl * far;
			var fpz = p.z + hz / hl * far;
			hcw = fpx * m._14 + p.y * m._24 + fpz * m._34 + m._44;
			var hproj = cam.project(fpx, p.y, fpz, 1, 1, false);
			hux = hproj.x;
			huy = hproj.y;
		}

		var s = fx.shader;
		s.sceneColor = @:privateAccess pbr.textures.hdr;
		s.depthTexture = pbr.getPbrDepth();
		s.inverseViewProj = cam.getInverseViewProj();
		s.cameraPos = new h3d.Vector(p.x, p.y, p.z);
		s.sunUV.set(uvx, uvy);
		s.sunValid = cw > 0.001 ? 1.0 : 0.0;
		s.horizonY = huy;
		s.horizonX = hux;
		s.horizonValid = hcw > 0.001 ? 1.0 : 0.0;
		s.maxElev = MAX_ELEV;
		s.glowColor.setColor(GLOW_COLOR);
		s.aspect = w / h;
		s.haloRadius = HALO_RADIUS;
		s.bandHeight = BAND_HEIGHT;
		s.bandWidth = BAND_WIDTH;
		s.skyMinDist = SKY_MIN_DIST;
		s.skyMaxDist = SKY_MAX_DIST;
		s.litSurfaces = LIT_SURFACES ? 1.0 : 0.0;

		// envelope: peak at the horizon (abs(elev) close to 0). The smoothstep
		// lives in the shader; here we pass the raw elevation + master scale.
		var elev = elevationSource != null ? elevationSource() : 1.0;
		s.elev = elev;
		s.inten = INTENSITY;

		ctx.engine.pushTarget(glowTarget);
		fx.render();
		ctx.engine.popTarget();
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || glowTarget == null || pbr == null)
			return;
		// ADDITIVE: stack the glow on top of the (fog+flare) hdr instead of
		// replacing it — this effect must be registered AFTER the lens flare.
		h3d.pass.Copy.run(glowTarget, @:privateAccess pbr.textures.hdr, h3d.mat.BlendMode.Add);
	}

	public function dispose()
	{
		if (glowTarget != null) glowTarget.dispose();
		glowTarget = null;
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