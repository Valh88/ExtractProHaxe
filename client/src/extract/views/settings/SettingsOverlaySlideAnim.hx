package extract.views.settings;

import extract.utils.SubView;
import extract.utils.animations.subswitchers.SubViewSwitchAnim;
import extract.utils.animations.AnimationController;
import extract.utils.animations.Easing;
import extract.utils.animations.VarTween;

/**
	Fade-in / fade-out transition for the settings overlay.

	Animates `design.alpha` (the SettingsDesign root Flow), which fades
	ALL children together: overlay, panel, buttons, tab content.
**/
class SettingsOverlaySlideAnim extends SubViewSwitchAnim
{
	var ctrl : AnimationController = new AnimationController();
	var target : h2d.Object;
	var duration : Float;
	var isClosing : Bool;

	public function new(from : SubView<Dynamic>, to : SubView<Dynamic>, target : h2d.Object,
			?duration : Float = 0.4, isClosing : Bool = false)
	{
		super(from, to);
		this.target = target;
		this.duration = duration;
		this.isClosing = isClosing;
	}

	override function begin() : Void
	{
		if (!isClosing)
		{
			// open: fade in entire design
			target.alpha = 0;
			ctrl.add(new VarTween(target, "alpha", 0, 1, duration, Easing.cubicOut));
		}
		else
		{
			// close: fade out from current state
			var startAlpha = target.alpha;
			ctrl.add(new VarTween(target, "alpha", startAlpha, 0, duration, Easing.cubicIn));
		}
	}

	override function tick(dt : Float) : Void
	{
		ctrl.update(dt);
		if (ctrl.count == 0) finish();
	}

	/** Override: close must NOT snap alpha = 1 (causes a flash). */
	override function finish() : Void
	{
		if (isComplete) return;
		if (isClosing)
			target.alpha = 0;
		else
			target.alpha = 1;
		if (from != null) from.design.visible = false;
		isRunning = false;
		isComplete = true;
		if (onComplete != null) onComplete();
	}

	override function cancel() : Void
	{
		ctrl.clear();
		super.cancel();
	}
}
