package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA16F;

class SettingsBlurShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		@param var sceneColor : Sampler2D;
		@param var blurSize : Vec2;
		@param var blurAmount : Float;

		function fragment() {
			var uv = calculatedUV;
			var col = sceneColor.get(uv) * 4.0;
			col += sceneColor.get(uv + vec2(-1.0, 0.0) * blurSize);
			col += sceneColor.get(uv + vec2( 1.0, 0.0) * blurSize);
			col += sceneColor.get(uv + vec2( 0.0,-1.0) * blurSize);
			col += sceneColor.get(uv + vec2( 0.0, 1.0) * blurSize);
			col += sceneColor.get(uv + vec2(-1.0,-1.0) * blurSize);
			col += sceneColor.get(uv + vec2( 1.0,-1.0) * blurSize);
			col += sceneColor.get(uv + vec2(-1.0, 1.0) * blurSize);
			col += sceneColor.get(uv + vec2( 1.0, 1.0) * blurSize);
			var blurred = col / 12.0;
			pixelColor = mix(sceneColor.get(uv), blurred, blurAmount);
		}
	}
}

class SettingsBlur implements RendererFX
{
	/** 0 = no blur, 1 = full blur. Animate this for a smooth transition. */
	public var enabled = false;

	var fx : h3d.pass.ScreenFx<SettingsBlurShader>;
	var blurTarget : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;
	var fog : DistanceFog;
	var amount : Float = 0.0;

	public function new(fog : DistanceFog, radius = 2.0)
	{
		this.fog = fog;
		fx = new h3d.pass.ScreenFx(new SettingsBlurShader());
		fx.shader.blurSize.set(radius / 1920.0, radius / 1080.0);
	}

	public function setAmount(v : Float) : Void
	{
		amount = v;
		enabled = v > 0.001;
		if (enabled) fx.shader.blurAmount = v;
	}

	public function start(r : h3d.scene.Renderer)
	{
		pbr = Std.downcast(r, h3d.scene.pbr.Renderer);
	}

	public function begin(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || pbr == null)
			return;
		// chain: blur the ALREADY-fogged frame, not the raw hdr — otherwise
		// end() would overwrite DistanceFog's result and "remove" the fog.
		var src = fog != null ? fog.blurSource : null;
		if (src == null)
			src = @:privateAccess pbr.textures.hdr;
		var ctx = @:privateAccess r.ctx;
		var w = ctx.engine.width;
		var h = ctx.engine.height;
		if (blurTarget == null || blurTarget.width != w || blurTarget.height != h)
		{
			if (blurTarget != null) blurTarget.dispose();
			blurTarget = ctx.textures.allocTarget("settingsBlur", w, h, false, RGBA16F);
		}
		fx.shader.sceneColor = src;
		ctx.engine.pushTarget(blurTarget);
		fx.render();
		ctx.engine.popTarget();
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || blurTarget == null || pbr == null)
			return;
		h3d.pass.Copy.run(blurTarget, @:privateAccess pbr.textures.hdr);
	}

	public function dispose()
	{
		if (blurTarget != null) blurTarget.dispose();
		blurTarget = null;
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
