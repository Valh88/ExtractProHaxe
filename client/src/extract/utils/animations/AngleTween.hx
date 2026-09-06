package extract.utils.animations;

/**
	Tweens the `rotation` property of an `h2d.Object` (radians).
	Supports shortest-path rotation: angles wrap around ±PI to take the
	shortest arc.

	Usage:
	  new AngleTween(obj, 0, Math.PI * 2, 2.0, Easing.sineInOut).start();
**/
class AngleTween extends AAnimation
{
	var from : Float;
	var to : Float;

	/**
		@param target   h2d.Object to animate
		@param from     start angle (radians)
		@param to       end angle (radians)
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, from : Float, to : Float, duration : Float, ?easing : Float -> Float)
	{
		this.from = from;
		this.to = to;
		super(target, duration, easing);
	}

	override public function start() : AAnimation
	{
		if (target != null) from = target.rotation;
		return super.start();
	}

	override function apply(t : Float) : Void
	{
		target.rotation = lerpAngle(from, to, t);
	}

	/** Shortest-path linear interpolation between two angles (radians). */
	static function lerpAngle(a : Float, b : Float, t : Float) : Float
	{
		var diff = b - a;
		// wrap to [-PI, PI]
		while (diff > Math.PI) diff -= 2.0 * Math.PI;
		while (diff < -Math.PI) diff += 2.0 * Math.PI;
		return a + diff * t;
	}
}
