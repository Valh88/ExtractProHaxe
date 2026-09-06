package extract.utils.animations;

typedef VarTweenEntry = {
	var prop : String;
	var to : Float;
};

/**
	Tweens multiple Float properties on an `h2d.Object` simultaneously.

	Usage:
	  new MultiVarTween(obj, [
	    { prop: "x", to: 200 },
	    { prop: "y", to: 100 },
	    { prop: "alpha", to: 0.5 }
	  ], 1.0, Easing.cubicOut).start();
**/
class MultiVarTween extends AAnimation
{
	var entries : Array<VarTweenEntry>;
	var fromValues : Array<Float>;

	/**
		@param target   h2d.Object to animate
		@param entries  list of { prop, to } pairs
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
			var v = Reflect.getField(target, e.prop);
			fromValues.push(Math.isNaN(v) ? 0 : v);
		}
		return super.start();
	}

	override function apply(t : Float) : Void
	{
		for (i in 0...entries.length)
		{
			var e = entries[i];
			Reflect.setField(target, e.prop, fromValues[i] + (e.to - fromValues[i]) * t);
		}
	}
}
