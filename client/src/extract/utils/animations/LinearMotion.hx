package extract.utils.animations;

/**
	Moves an `h2d.Object` along a straight line from (x1,y1) to (x2,y2).

	Usage:
	  new LinearMotion(obj, 0, 0, 200, 100, 1.0, Easing.quadOut).start();
**/
class LinearMotion extends AAnimation
{
	var x1 : Float;
	var y1 : Float;
	var x2 : Float;
	var y2 : Float;

	/**
		@param target   h2d.Object to move
		@param x1,y1    start position
		@param x2,y2    end position
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, x1 : Float, y1 : Float, x2 : Float, y2 : Float, duration : Float,
			?easing : Float -> Float)
	{
		this.x1 = x1;
		this.y1 = y1;
		this.x2 = x2;
		this.y2 = y2;
		super(target, duration, easing);
	}

	override function apply(t : Float) : Void
	{
		target.x = x1 + (x2 - x1) * t;
		target.y = y1 + (y2 - y1) * t;
	}
}
