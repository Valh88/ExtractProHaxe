package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA16F;

/** Screen-space lens flare for the visible sun disc.

    Full-screen additive pass that draws a row of lens ghosts along the
    screen-center→sun axis. The ghost chain is anchored to the sun's live
    projected position (sunUV), so it moves and rotates with the sun exactly.
    Occlusion is a single depth probe at the sun: if geometry sits in front of
    the disc the whole flare fades out. Runs BEFORE tonemapping (same step as
    {@link DistanceFog}) so values > 1 feed the tone mapper and read as glare. */
class LensFlareShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		@param var sceneColor : Sampler2D;
		@param var depthTexture : Sampler2D;
		@param var inverseViewProj : Mat4;
		@param var cameraPos : Vec3;
		/** Sun disc world radius (m). */
		@param var sunRadius : Float;
		/** Sun disc center in texture uv space (0..1, y up). */
		@param var sunUV : Vec2;
		/** 1 when the sun is in front of the camera and near the frame, else 0. */
		@param var sunValid : Float;
		/** Camera→sun distance (m), the occlusion reference. */
		@param var sunDist : Float;
		/** Master intensity including the elevation (night) fade. */
		@param var inten : Float;
		/** Screen width/height — keeps the round ghosts circular. */
		@param var aspect : Float;
		/** Multiplier for the ghost radii (drives the ghost chain size). */
		@param var ghostScale : Float;
		/** Sun disc radius in screen uv (vertical); drives the occlusion sampling. */
		@param var sunUvRadius : Float;

		/** Radial gradient of a single ghost: 1 at `center`, 0 at `radius`. */
		function ghost(uv : Vec2, center : Vec2, radius : Float, falloff : Float) : Float {
			var d = (uv - center) * vec2(aspect, 1.0);
			return pow(max(1.0 - length(d) / radius, 0.0), falloff);
		}

		/** Visibility of one screen point: 1 when nothing is in front of the sun
		    at that point, 0 when geometry sits meaningfully nearer. Reconstructs
		    the world position of the depth sample and compares it to the FRONT
		    face of the disc (sunDist - sunRadius). */
		function occlusionAt(p : Vec2) : Float {
			var dt = depthTexture.get(p).r;
			var temp = vec4(uvToScreen(p), dt, 1.0) * inverseViewProj;
			var wp = temp.xyz / temp.w;
			var dWall = distance(wp, cameraPos);
			var discFront = sunDist - sunRadius;
			return smoothstep(discFront - 4.0, discFront - 0.5, dWall);
		}

		function fragment() {
			var uv = calculatedUV;
			var col = sceneColor.get(uv);

			// occlusion: average several depth probes across the disc, so a
			// partial cover fades the flare partially instead of a single point
			// blocking the whole halo. uv radius is anisotropic (screen aspect).
			var rx = sunUvRadius / aspect;
			var ry = sunUvRadius;
			var occ = occlusionAt(sunUV);
			occ += occlusionAt(sunUV + vec2(rx * 0.7, 0.0));
			occ += occlusionAt(sunUV - vec2(rx * 0.7, 0.0));
			occ += occlusionAt(sunUV + vec2(0.0, ry * 0.7));
			occ += occlusionAt(sunUV - vec2(0.0, ry * 0.7));
			occ /= 5.0;

			// fade the whole flare as the sun leaves the frame
			var edge = smoothstep(-0.2, 0.02, sunUV.x) * smoothstep(1.2, 0.98, sunUV.x)
				* smoothstep(-0.2, 0.02, sunUV.y) * smoothstep(1.2, 0.98, sunUV.y);

			var f = occ * edge * sunValid * inten;

			var warm = vec3(1.0, 0.82, 0.52);
			var cool = vec3(0.55, 0.70, 1.0);
			var violet = vec3(0.85, 0.65, 1.0);

			var flare = vec3(0.0);
			// hot core: small, bright center so the sun still reads as a disc
			// even with the mesh hidden (radius is in screen-height units)
			flare += vec3(1.0, 0.95, 0.85) * 3.0 * ghost(uv, sunUV, 0.03, 5.0);
			// main warm glow around the core (radius is in units of screen
			// height; ~1.6x the visible disc so it reads as a halo around it)
			flare += warm * 2.2 * ghost(uv, sunUV, 0.15, 4.0);
			// ghosts on the center<->sun line (warm near the sun,
			// cool/violet further out — cheap chromatic dispersion)
			var c = vec2(0.5, 0.5);
			var dir = sunUV - c;
			var gs = ghostScale;
			flare += warm * 0.55 * ghost(uv, c + dir * 0.85, 0.030 * gs, 7.0);
			flare += warm * 0.35 * ghost(uv, c + dir * 0.60, 0.018 * gs, 8.0);
			flare += cool * 0.28 * ghost(uv, c + dir * 0.38, 0.012 * gs, 9.0);
			flare += violet * 0.22 * ghost(uv, c + dir * 0.18, 0.008 * gs, 10.0);
			flare += cool * 0.18 * ghost(uv, c - dir * 0.30, 0.010 * gs, 9.0);

			pixelColor = col + vec4(flare * f, 0.0);
		}
	}
}

class LensFlare implements h3d.impl.RendererFX
{
	public var enabled = true;

	/** Master HDR multiplier of the flare. */
	public static var INTENSITY : Float = 1.0;
	/** Below the horizon the flare fades: factor = 1 + elevation * ELEV_FADE. */
	public static var ELEV_FADE : Float = 6.0;
	/** Screen uv margin (beyond the frame) where the edge fade starts. */
	public static var EDGE_MARGIN : Float = 0.2;
	/** Size multiplier for the ghost circles (1 = default, 0 = hidden). */
	public static var GHOST_SCALE : Float = 5.0;

	/** World-space sun position (shared ref, mutated each frame by SunSystem). */
	public var sunPos : h3d.Vector = new h3d.Vector();
	/** World-space sun disc radius (m), for the occlusion reference. */
	public var sunRadius : Float = 25.0;
	/** Sun elevation (sin of the angle above the horizon) — for the night fade. */
	public var elevationSource : Null<Void -> Float> = null;

	var fx : h3d.pass.ScreenFx<LensFlareShader>;
	var flareTarget : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;
	var fog : Null<DistanceFog>;

	public function new(?fog : DistanceFog)
	{
		this.fog = fog;
		fx = new h3d.pass.ScreenFx(new LensFlareShader());
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
		if (flareTarget == null || flareTarget.width != w || flareTarget.height != h)
		{
			if (flareTarget != null) flareTarget.dispose();
			flareTarget = ctx.textures.allocTarget("lensflare", w, h, false, RGBA16F);
		}

		// project the sun disc center into texture uv. camera.project already
		// returns 0..1 with y DOWN, which matches calculatedUV (screenToUv) —
		// no vertical flip, otherwise the flare mirrors away from the disc.
		var cam = ctx.camera;
		var m = cam.m;
		var cw = sunPos.x * m._14 + sunPos.y * m._24 + sunPos.z * m._34 + m._44;
		var proj = cam.project(sunPos.x, sunPos.y, sunPos.z, 1, 1, false);
		var uvx = proj.x;
		var uvy = proj.y;
		var p = cam.pos;
		var dx = sunPos.x - p.x, dy = sunPos.y - p.y, dz = sunPos.z - p.z;
		var sunDist = Math.sqrt(dx * dx + dy * dy + dz * dz);
		var inFrame = uvx >= -EDGE_MARGIN && uvx <= 1 + EDGE_MARGIN
			&& uvy >= -EDGE_MARGIN && uvy <= 1 + EDGE_MARGIN;

		// disc radius in screen uv (vertical): the screen height at distance d
		// spans 2*d*tan(fovY/2), so a world radius r covers r/(d*tan(fovY/2)).
		var sunUvRadius = sunRadius / (sunDist * Math.tan(cam.fovY * 0.5 * Math.PI / 180));

		var s = fx.shader;
		s.sceneColor = fog != null ? fog.blurSource : @:privateAccess pbr.textures.hdr;
		s.depthTexture = pbr.getPbrDepth();
		s.inverseViewProj = cam.getInverseViewProj();
		s.cameraPos = new h3d.Vector(p.x, p.y, p.z);
		s.sunRadius = sunRadius;
		s.sunUV.set(uvx, uvy);
		s.sunDist = sunDist;
		s.aspect = w / h;
		s.ghostScale = GHOST_SCALE;
		s.sunUvRadius = sunUvRadius;
		s.sunValid = (cw > 0.001 && inFrame) ? 1.0 : 0.0;
		var elev = elevationSource != null ? elevationSource() : 1.0;
		s.inten = INTENSITY * hxd.Math.clamp(1.0 + elev * ELEV_FADE, 0.0, 3.0);

		ctx.engine.pushTarget(flareTarget);
		fx.render();
		ctx.engine.popTarget();
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || flareTarget == null || pbr == null)
			return;
		h3d.pass.Copy.run(flareTarget, @:privateAccess pbr.textures.hdr);
	}

	public function dispose()
	{
		if (flareTarget != null) flareTarget.dispose();
		flareTarget = null;
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
