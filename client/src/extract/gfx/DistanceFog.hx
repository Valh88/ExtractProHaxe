package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA16F;

class DistanceFogShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		@param var sceneColor : Sampler2D;
		@param var depthTexture : Sampler2D;
		@param var inverseViewProj : Mat4;
		@param var cameraPos : Vec3;
		@param var fogColor : Vec3;
		@param var fogStart : Float;
		@param var fogEnd : Float;
		@param var fogHeightFalloff : Float;

		function fragment() {
			var uv = calculatedUV;
			var d = depthTexture.get(uv).r;
			// reconstruct world position from depth (same trick as h3d.shader.Blur.hx)
			var temp = vec4(uvToScreen(uv), d, 1.0) * inverseViewProj;
			var wp = temp.xyz / temp.w;
			var dist = distance(wp, cameraPos);
			var f = clamp(smoothstep(fogStart, fogEnd, dist), 0.0, 1.0);
			// height fade: fog thins out above the camera
			f *= exp(-max(cameraPos.y - wp.y, 0.0) * fogHeightFalloff);
			var col = sceneColor.get(uv);
			pixelColor = vec4(mix(col.rgb, fogColor, f), col.a);
		}
	}
}

class DistanceFog implements h3d.impl.RendererFX
{
	public var enabled = true;

	var fx = new h3d.pass.ScreenFx(new DistanceFogShader());
	var fogTarget : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;

	/** Post-fog result — lets later effects (e.g. SettingsBlur) chain off it instead of raw hdr. */
	public var blurSource(get, never) : h3d.mat.Texture;
	function get_blurSource() return fogTarget;

	public function new(fogColor = 0x8FA3B5, fogStart = 40.0, fogEnd = 200.0, fogHeightFalloff = 0.05)
	{
		var s = fx.shader;
		s.fogColor.setColor(fogColor);
		s.fogStart = fogStart;
		s.fogEnd = fogEnd;
		s.fogHeightFalloff = fogHeightFalloff;
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
		if (fogTarget == null || fogTarget.width != w || fogTarget.height != h)
		{
			if (fogTarget != null) fogTarget.dispose();
			fogTarget = ctx.textures.allocTarget("fog", w, h, false, RGBA16F);
		}
		var s = fx.shader;
		s.sceneColor = @:privateAccess pbr.textures.hdr;
		s.depthTexture = pbr.getPbrDepth();
		s.inverseViewProj = ctx.camera.getInverseViewProj();
		var p = ctx.camera.pos;
		s.cameraPos = new h3d.Vector(p.x, p.y, p.z);
		ctx.engine.pushTarget(fogTarget);
		fx.render();
		ctx.engine.popTarget();
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || fogTarget == null || pbr == null)
			return;
		h3d.pass.Copy.run(fogTarget, @:privateAccess pbr.textures.hdr);
	}

	public function dispose()
	{
		if (fogTarget != null) fogTarget.dispose();
		fogTarget = null;
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