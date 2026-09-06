package extract.utils.animations;

/**
	Manages a collection of active animations and advances them each frame.
	Create one per scene (GamePlayView, LobbyView) and call `update(dt)` from
	the scene's update method.

	Usage:
	  var ctrl = new AnimationController();
	  ctrl.add(new VarTween(obj, "x", 200, 1.0, Easing.quadOut));
	  // in scene update:
	  ctrl.update(dt);
**/
class AnimationController
{
	var animations : Array<AAnimation> = [];

	public function new() {}

	/** Register an animation and start it. Returns the animation for chaining. */
	public function add(anim : AAnimation) : AAnimation
	{
		if (animations.indexOf(anim) < 0) animations.push(anim);
		if (!anim.isRunning && !anim.isComplete) anim.start();
		return anim;
	}

	/** Remove an animation from the controller. */
	public function remove(anim : AAnimation) : Void
	{
		animations.remove(anim);
	}

	/** Remove all animations. */
	public function clear() : Void
	{
		animations.resize(0);
	}

	/** Advance all active animations by `dt` seconds. Call once per frame. */
	public function update(dt : Float) : Void
	{
		var i = animations.length - 1;
		while (i >= 0)
		{
			var a = animations[i];
			a.update(dt);
			if (a.isComplete)
				animations.splice(i, 1);
			i--;
		}
	}

	/** Number of active (non-complete) animations. */
	public var count(get, never) : Int;

	function get_count() : Int
		return animations.length;
}
