package extract.utils.animations.subswitchers;

import extract.utils.SubView;
import extract.utils.animations.AnimationController;
import extract.utils.animations.Easing;
import extract.utils.animations.VarTween;

/**
	Default sub-view switch: the outgoing view slides away and fades out,
	the incoming one slides in from the opposite side and fades in.

	`dir = 1` → `to` enters from the right, `from` exits to the left;
	`dir = -1` mirrors it. `slide` is the travel distance (usually the
	parent container width).
**/
class SlideFadeSwitchAnim extends SubViewSwitchAnim
{
	var ctrl : AnimationController = new AnimationController();

	final dir : Float;
	final slide : Float;
	final duration : Float;

	public function new(from : SubView<Dynamic>, to : SubView<Dynamic>, dir : Float,
			slide : Float, ?duration : Float = 0.35)
	{
		super(from, to);
		this.dir = dir;
		this.slide = slide;
		this.duration = duration;
	}

	override function begin() : Void
	{
		var toD : h2d.Flow = cast to.design;
		var fromD : h2d.Flow = cast from.design;

		fromD.x = 0;
		fromD.alpha = 1;
		fromD.visible = true;

		toD.x = dir * slide;
		toD.alpha = 0;
		toD.visible = true;

		ctrl.add(new VarTween(toD, "x", dir * slide, 0, duration, Easing.cubicOut));
		ctrl.add(new VarTween(toD, "alpha", 0, 1, duration, Easing.cubicOut));
		ctrl.add(new VarTween(fromD, "x", 0, -dir * slide, duration, Easing.cubicIn));
		ctrl.add(new VarTween(fromD, "alpha", 1, 0, duration, Easing.cubicIn));
	}

	override function tick(dt : Float) : Void
	{
		ctrl.update(dt);
		if (ctrl.count == 0) finish();
	}

	override function cancel() : Void
	{
		ctrl.clear();
		super.cancel();
	}
}