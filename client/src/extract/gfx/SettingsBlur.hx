package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA16F;

/** 9-tap gaussian pass along X. Weight sum ≈ 1.0 (σ≈2 taps). */
class SettingsBlurHShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		@param var sceneColor : Sampler2D;
		@param var blurSize : Float;

		function fragment() {
			var uv = calculatedUV;
			var col = sceneColor.get(uv) * 0.227027;
			col += sceneColor.get(uv + vec2( 1.0, 0.0) * blurSize) * 0.1945946;
			col += sceneColor.get(uv - vec2( 1.0, 0.0) * blurSize) * 0.1945946;
			col += sceneColor.get(uv + vec2( 2.0, 0.0) * blurSize) * 0.1216216;
			col += sceneColor.get(uv - vec2( 2.0, 0.0) * blurSize) * 0.1216216;
			col += sceneColor.get(uv + vec2( 3.0, 0.0) * blurSize) * 0.0540540;
			col += sceneColor.get(uv - vec2( 3.0, 0.0) * blurSize) * 0.0540540;
			col += sceneColor.get(uv + vec2( 4.0, 0.0) * blurSize) * 0.0162162;
			col += sceneColor.get(uv - vec2( 4.0, 0.0) * blurSize) * 0.0162162;
			pixelColor = col;
		}
	}
}

/** 9-tap gaussian pass along Y. Mixes with `origColor` by `blurAmount`
	(blurAmount=1 on intermediate iterations → pure blur; on the final pass
	blurAmount = UI fade → blends original ⇄ blurred). */
class SettingsBlurVShader extends h3d.shader.ScreenShader
{
	static var SRC = {
		@param var sceneColor : Sampler2D;
		@param var origColor : Sampler2D;
		@param var blurSize : Float;
		@param var blurAmount : Float;

		function fragment() {
			var uv = calculatedUV;
			var col = sceneColor.get(uv) * 0.227027;
			col += sceneColor.get(uv + vec2( 0.0, 1.0) * blurSize) * 0.1945946;
			col += sceneColor.get(uv - vec2( 0.0, 1.0) * blurSize) * 0.1945946;
			col += sceneColor.get(uv + vec2( 0.0, 2.0) * blurSize) * 0.1216216;
			col += sceneColor.get(uv - vec2( 0.0, 2.0) * blurSize) * 0.1216216;
			col += sceneColor.get(uv + vec2( 0.0, 3.0) * blurSize) * 0.0540540;
			col += sceneColor.get(uv - vec2( 0.0, 3.0) * blurSize) * 0.0540540;
			col += sceneColor.get(uv + vec2( 0.0, 4.0) * blurSize) * 0.0162162;
			col += sceneColor.get(uv - vec2( 0.0, 4.0) * blurSize) * 0.0162162;
			pixelColor = mix(origColor.get(uv), col, blurAmount);
		}
	}
}

class SettingsBlur implements RendererFX
{
	public var enabled = false;

	var fxH : h3d.pass.ScreenFx<SettingsBlurHShader>;
	var fxV : h3d.pass.ScreenFx<SettingsBlurVShader>;
	var origTarget : h3d.mat.Texture;
	var blurA : h3d.mat.Texture;
	var blurB : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;
	var fog : DistanceFog;
	var radius : Float;
	var iterations : Int;
	var amount : Float = 0.0;

	/**
		@param radius      tap spacing in px (blur width per pass)
		@param iterations  H+V passes; effective σ ≈ 2·radius·√iterations px.
		(4, 4) → ≈30px effective span — real soap; tune down for subtle.
	**/
	public function new(fog : DistanceFog, radius = 4.0, iterations = 4)
	{
		this.fog = fog;
		this.radius = radius;
		this.iterations = iterations > 0 ? iterations : 1;
		fxH = new h3d.pass.ScreenFx(new SettingsBlurHShader());
		fxV = new h3d.pass.ScreenFx(new SettingsBlurVShader());
	}

	public function setAmount(v : Float) : Void
	{
		amount = v;
		enabled = v > 0.001;
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
		if (origTarget == null || origTarget.width != w || origTarget.height != h)
		{
			for (t in [origTarget, blurA, blurB]) if (t != null) t.dispose();
			origTarget = ctx.textures.allocTarget("blurOrig", w, h, false, RGBA16F);
			blurA = ctx.textures.allocTarget("blurA", w, h, false, RGBA16F);
			blurB = ctx.textures.allocTarget("blurB", w, h, false, RGBA16F);
		}

		// keep pristine input for the final orig⇄blur mix
		h3d.pass.Copy.run(src, origTarget);

		fxH.shader.blurSize = radius / w;
		fxV.shader.blurSize = radius / h;

		var cur = src;
		for (i in 0...iterations)
		{
			// horizontal pass → blurA
			fxH.shader.sceneColor = cur;
			ctx.engine.pushTarget(blurA);
			fxH.render();
			ctx.engine.popTarget();

			// vertical pass → blurB; final iteration mixes with original
			var last = (i == iterations - 1);
			fxV.shader.sceneColor = blurA;
			fxV.shader.origColor = last ? origTarget : blurA;
			fxV.shader.blurAmount = last ? amount : 1.0;
			ctx.engine.pushTarget(blurB);
			fxV.render();
			ctx.engine.popTarget();

			cur = blurB;
		}
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || blurB == null || pbr == null)
			return;
		h3d.pass.Copy.run(blurB, @:privateAccess pbr.textures.hdr);
	}

	public function dispose()
	{
		for (t in [origTarget, blurA, blurB]) if (t != null) t.dispose();
		origTarget = null;
		blurA = null;
		blurB = null;
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