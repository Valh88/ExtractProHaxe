package extract.utils.animations;

/**
	Moves an `h2d.Object` along a quadratic bezier curve defined by three
	control points: P0 (start), P1 (control), P2 (end).

	Quadratic bezier formula:
	  B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2

	Usage:
	  new QuadMotion(obj, 0,0, 100,150, 200,0, 1.5).start();
**/
class QuadMotion extends AAnimation
{
	var x0 : Float;
	var y0 : Float;
	var cx : Float;
	var cy : Float;
	var x1 : Float;
	var y1 : Float;

	/**
		@param target   h2d.Object to move
		@param x0,y0    start point (P0)
		@param cx,cy    control point (P1)
		@param x1,y1    end point (P2)
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, x0 : Float, y0 : Float, cx : Float, cy : Float, x1 : Float, y1 : Float,
			duration : Float, ?easing : Float -> Float)
	{
		this.x0 = x0;
		this.y0 = y0;
		this.cx = cx;
		this.cy = cy;
		this.x1 = x1;
		this.y1 = y1;
		super(target, duration, easing);
	}

	function apply(t : Float) : Void
	{
		var u = 1.0 - t;
		target.x = u * u * x0 + 2.0 * u * t * cx + t * t * x1;
		target.y = u * u * y0 + 2.0 * u * t * cy + t * t * y1;
	}
}
