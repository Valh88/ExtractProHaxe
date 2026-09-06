package extract.utils.animations;

/**
	Tweens a single Float property on an `h2d.Object`.

	Usage:
	  new VarTween(obj, "x", 200, 1.0, Easing.quadOut).start();
	  new VarTween(obj, "alpha", 0, 1, 0.5, Easing.sineIn).start();
**/
class VarTween extends AAnimation
{
	var prop : String;
	var fromVal : Float;
	var toVal : Float;
	var hasFrom : Bool;

	/**
		@param target   h2d.Object to animate
		@param prop     property name (e.g. "x", "alpha", "scaleX")
		@param from     start value (omit or NaN to read from target at start())
		@param to       end value
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, prop : String, from : Float, to : Float, duration : Float,
			?easing : Float -> Float)
	{
		this.prop = prop;
		this.fromVal = from;
		this.toVal = to;
		this.hasFrom = !Math.isNaN(from);
		super(target, duration, easing);
	}

	override public function start() : AAnimation
	{
		if (!hasFrom)
		{
			var v : Float = switch prop
			{
				case "x": target.x;
				case "y": target.y;
				case "alpha": target.alpha;
				case "scaleX": target.scaleX;
				case "scaleY": target.scaleY;
				case "rotation": target.rotation;
				default: Reflect.field(target, prop);
			};
			fromVal = Math.isNaN(v) ? 0 : v;
		}
		return super.start();
	}

	function apply(t : Float) : Void
	{
		var v = fromVal + (toVal - fromVal) * t;
		switch prop
		{
			case "x": target.x = v;
			case "y": target.y = v;
			case "alpha": target.alpha = v;
			case "scaleX": target.scaleX = v;
			case "scaleY": target.scaleY = v;
			case "rotation": target.rotation = v;
			default: Reflect.setField(target, prop, v);
		}
	}
}
