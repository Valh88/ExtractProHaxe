package extract.utils.animations;

/**
	Moves an `h2d.Object` along a multi-segment quadratic bezier path.
	Each segment is a quadratic curve from the current point to the next,
	using the midpoint between consecutive waypoints as the control point.

	For n waypoints, there are n-1 quadratic segments:
	  segment[i]: P[i] → midpoint(P[i], P[i+1]) → P[i+1]

	Usage:
	  new QuadPath(obj, [{x:0,y:0}, {x:100,y:50}, {x:200,y:0}], 2.0).start();
**/
class QuadPath extends AAnimation
{
	var points : Array<{x : Float, y : Float}>;
	var totalSegments : Int;

	/**
		@param target   h2d.Object to move
		@param points   array of {x, y} waypoints (minimum 2)
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, points : Array<{x : Float, y : Float}>, duration : Float,
			?easing : Float -> Float)
	{
		this.points = points;
		this.totalSegments = points.length - 1;
		super(target, duration, easing);
	}

	function apply(t : Float) : Void
	{
		if (totalSegments <= 0) return;

		// map t (0..1) to segment index + local t
		var scaled = t * totalSegments;
		var seg = Std.int(scaled);
		if (seg >= totalSegments) seg = totalSegments - 1;
		var localT = scaled - seg;

		var p0 = points[seg];
		var p2 = points[seg + 1];

		// control point = midpoint between p0 and p2
		var cpx = (p0.x + p2.x) * 0.5;
		var cpy = (p0.y + p2.y) * 0.5;

		var u = 1.0 - localT;
		target.x = u * u * p0.x + 2.0 * u * localT * cpx + localT * localT * p2.x;
		target.y = u * u * p0.y + 2.0 * u * localT * cpy + localT * localT * p2.y;
	}
}
