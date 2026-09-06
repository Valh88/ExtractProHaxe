package extract.utils.animations;

typedef VarTweenEntry = {
	var prop : String;
	/** Start value. If null, reads current value from target at start(). */
	@:optional var from : Null<Float>;
	var to : Float;
};

/**
	Tweens multiple Float properties on an `h2d.Object` simultaneously.

	Usage:
	  new MultiVarTween(obj, [
	    { prop: "x", from: 0, to: 200 },
	    { prop: "alpha", from: 0.0, to: 1.0 }
	  ], 1.0, Easing.cubicOut).start();
**/
class MultiVarTween extends AAnimation
{
	var entries : Array<VarTweenEntry>;
	var fromValues : Array<Float>;

	/**
		@param target   h2d.Object to animate
		@param entries  list of { prop, from?(null=read target), to } pairs
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, entries : Array<VarTweenEntry>, duration : Float, ?easing : Float -> Float)
	{
		this.entries = entries;
		this.fromValues = [];
		super(target, duration, easing);
	}

	override public function start() : AAnimation
	{
		fromValues = [];
		for (e in entries)
		{
			if (e.from != null)
				fromValues.push(e.from);
			else
			{
				var v : Float = switch e.prop
				{
					case "x": target.x;
					case "y": target.y;
					case "alpha": target.alpha;
					case "scaleX": target.scaleX;
					case "scaleY": target.scaleY;
					case "rotation": target.rotation;
					default: Reflect.field(target, e.prop);
				};
				fromValues.push(Math.isNaN(v) ? 0 : v);
			}
		}
		return super.start();
	}

	function apply(t : Float) : Void
	{
		for (i in 0...entries.length)
		{
			var e = entries[i];
			var v = fromValues[i] + (e.to - fromValues[i]) * t;
			switch e.prop
			{
				case "x": target.x = v;
				case "y": target.y = v;
				case "alpha": target.alpha = v;
				case "scaleX": target.scaleX = v;
				case "scaleY": target.scaleY = v;
				case "rotation": target.rotation = v;
				default: Reflect.setField(target, e.prop, v);
			}
		}
	}
}
