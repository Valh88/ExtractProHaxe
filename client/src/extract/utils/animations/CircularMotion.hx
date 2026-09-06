package extract.utils.animations;

/**
	Moves an `h2d.Object` along a circular arc defined by center, radius,
	start angle, and end angle (radians).

	Usage:
	  new CircularMotion(obj, 400, 300, 100, 0, Math.PI, 2.0).start();
**/
class CircularMotion extends AAnimation
{
	var cx : Float;
	var cy : Float;
	var radius : Float;
	var startAngle : Float;
	var endAngle : Float;

	/**
		@param target     h2d.Object to move
		@param cx,cy      center of the circle
		@param radius     circle radius
		@param startAngle start angle in radians
		@param endAngle   end angle in radians
		@param duration   seconds
		@param easing     easing function (null → linear)
	**/
	public function new(target : h2d.Object, cx : Float, cy : Float, radius : Float, startAngle : Float,
			endAngle : Float, duration : Float, ?easing : Float -> Float)
	{
		this.cx = cx;
		this.cy = cy;
		this.radius = radius;
		this.startAngle = startAngle;
		this.endAngle = endAngle;
		super(target, duration, easing);
	}

	function apply(t : Float) : Void
	{
		var angle = startAngle + (endAngle - startAngle) * t;
		target.x = cx + Math.cos(angle) * radius;
		target.y = cy + Math.sin(angle) * radius;
	}
}
