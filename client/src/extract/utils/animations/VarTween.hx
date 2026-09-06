package extract.utils.animations;

/**
	Tweens a single Float property on an `h2d.Object`.

	Usage:
	  new VarTween(obj, "x", 200, 1.0, Easing.quadOut).start();
	  new VarTween(obj, "alpha", 0, 0.5, Easing.sineIn).start();
**/
class VarTween extends AAnimation
{
	var prop : String;
	var from : Float;
	var to : Float;
	var fromCache : Float;

	/**
		@param target   h2d.Object to animate
		@param prop     property name (e.g. "x", "alpha", "scaleX")
		@param to       target value (absolute, or relative if `relative=true`)
		@param duration seconds
		@param easing   easing function (null → linear)
		@param relative if true, `from` = current value at start, `to` = delta
	**/
	public function new(target : h2d.Object, prop : String, to : Float, duration : Float, ?easing : Float -> Float,
			relative : Bool = false)
	{
		this.prop = prop;
		this.to = to;
		this.from = 0;
		this.fromCache = 0;
		super(target, duration, easing);
		if (!relative) fromCache = to; // store for non-relative mode
	}

	override public function start() : AAnimation
	{
		from = Reflect.getField(target, prop);
		if (Math.isNaN(from)) from = 0;
		fromCache = from;
		return super.start();
	}

	override function apply(t : Float) : Void
	{
		Reflect.setField(target, prop, fromCache + (to - fromCache) * t);
	}
}
