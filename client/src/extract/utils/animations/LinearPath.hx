package extract.utils.animations;

/**
	Moves an `h2d.Object` along a polyline (array of points).
	The animation is evenly distributed across all segments.

	Usage:
	  new LinearPath(obj, [{x:0,y:0}, {x:100,y:50}, {x:200,y:0}], 2.0).start();
**/
class LinearPath extends AAnimation
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

	override function apply(t : Float) : Void
	{
		if (totalSegments <= 0) return;

		// map t (0..1) to segment index + local t
		var scaled = t * totalSegments;
		var seg = Std.int(scaled);
		if (seg >= totalSegments) seg = totalSegments - 1;
		var localT = scaled - seg;

		var a = points[seg];
		var b = points[seg + 1];
		target.x = a.x + (b.x - a.x) * localT;
		target.y = a.y + (b.y - a.y) * localT;
	}
}
