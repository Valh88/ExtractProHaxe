package extract.gfx;

import h3d.impl.RendererFX;
import hxd.PixelFormat.RGBA;
import h2d.BlendMode.Multiply;
import hxsl.Channel;

class ScalableAO implements RendererFX
{
	public var enabled = true;

	public static var SAMPLE_RADIUS = 0.2;
	public static var NUM_SAMPLES = 30;
	public static var INTENSITY = 1.0;
	public static var BIAS = 0.01;
	public static var BLUR_RADIUS = 1.0;
	public static var BLUR_QUALITY = 1.0;
	public static var BLUR_LINEAR = 0.0;

	var sao : h3d.pass.ScalableAO;
	var blur : h3d.pass.Blur;
	var aoTarget : h3d.mat.Texture;
	var pbr : h3d.scene.pbr.Renderer;

	public function new()
	{
		sao = new h3d.pass.ScalableAO();
		sao.shader.sampleRadius = SAMPLE_RADIUS;
		sao.shader.numSamples = NUM_SAMPLES;
		sao.shader.intensity = INTENSITY;
		sao.shader.bias = BIAS;
		blur = new h3d.pass.Blur(BLUR_RADIUS, 1, BLUR_LINEAR, BLUR_QUALITY);
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
		if (aoTarget == null || aoTarget.width != w || aoTarget.height != h)
		{
			if (aoTarget != null) aoTarget.dispose();
			aoTarget = ctx.textures.allocTarget("sao", w, h, false, RGBA);
		}
		ctx.engine.pushTarget(aoTarget);
		sao.shader.depthTextureChannel = R;
		sao.shader.normalTextureChannel = R;
		sao.apply(pbr.getPbrDepth(), @:privateAccess pbr.textures.normal, ctx.camera);
		ctx.engine.popTarget();
		blur.apply(ctx, aoTarget);
	}

	public function end(r : h3d.scene.Renderer, step : Step)
	{
		if (!enabled || step != BeforeTonemapping || aoTarget == null || pbr == null)
			return;
		h3d.pass.Copy.run(aoTarget, @:privateAccess pbr.textures.hdr, Multiply);
	}

	public function dispose()
	{
		if (aoTarget != null) aoTarget.dispose();
		aoTarget = null;
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