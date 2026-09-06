package extract.utils.animations;

/**
	Moves an `h2d.Object` along a cubic bezier curve defined by four control
	points: P0 (start), P1, P2, P3 (end).

	Bézier formula:
	  B(t) = (1-t)³·P0 + 3(1-t)²t·P1 + 3(1-t)t²·P2 + t³·P3

	Usage:
	  new CubicMotion(obj, 0,0, 50,100, 150,100, 200,0, 2.0).start();
**/
class CubicMotion extends AAnimation
{
	var x0 : Float;
	var y0 : Float;
	var x1 : Float;
	var y1 : Float;
	var x2 : Float;
	var y2 : Float;
	var x3 : Float;
	var y3 : Float;

	/**
		@param target   h2d.Object to move
		@param x0,y0    start point (P0)
		@param x1,y1    control point 1 (P1)
		@param x2,y2    control point 2 (P2)
		@param x3,y3    end point (P3)
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, x0 : Float, y0 : Float, x1 : Float, y1 : Float, x2 : Float, y2 : Float,
			x3 : Float, y3 : Float, duration : Float, ?easing : Float -> Float)
	{
		this.x0 = x0;
		this.y0 = y0;
		this.x1 = x1;
		this.y1 = y1;
		this.x2 = x2;
		this.y2 = y2;
		this.x3 = x3;
		this.y3 = y3;
		super(target, duration, easing);
	}

	function apply(t : Float) : Void
	{
		var u = 1.0 - t;
		var tt = t * t;
		var uu = u * u;
		var uuu = uu * u;
		var ttt = tt * t;

		target.x = uuu * x0 + 3.0 * uu * t * x1 + 3.0 * u * tt * x2 + ttt * x3;
		target.y = uuu * y0 + 3.0 * uu * t * y1 + 3.0 * u * tt * y2 + ttt * y3;
	}
}
