package extract.utils.animations;

/**
	Tweens a raw Float value (not bound to any object property).
	Access the current value via `value`. Use `onUpdate` to react
	to changes.

	Usage:
	  var tween = new NumTween(0, 100, 1.0, Easing.quadOut);
	  tween.onUpdate = (v) -> trace("value = " + v);
	  tween.start();
**/
class NumTween extends AAnimation
{
	/** Current animated value. */
	public var value(default, null) : Float;

	var from : Float;
	var to : Float;

	/**
		@param from     start value
		@param to       end value
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(from : Float, to : Float, duration : Float, ?easing : Float -> Float)
	{
		this.from = from;
		this.to = to;
		this.value = from;
		super(null, duration, easing);
	}

	override function apply(t : Float) : Void
	{
		value = from + (to - from) * t;
	}
}
