package extract.utils.animations;

/**
	Static easing functions for tween animations.
	Each function maps `t ∈ [0,1]` to a curved output `[0,1]`.
**/
class Easing
{
	// --- linear ---

	public static inline function linear(t : Float) : Float
		return t;

	// --- quad ---

	public static inline function quadIn(t : Float) : Float
		return t * t;

	public static inline function quadOut(t : Float) : Float
		return t * (2.0 - t);

	public static inline function quadInOut(t : Float) : Float
		return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t;

	// --- cubic ---

	public static inline function cubicIn(t : Float) : Float
		return t * t * t;

	public static inline function cubicOut(t : Float) : Float
	{
		var u = t - 1.0;
		return u * u * u + 1.0;
	}

	public static inline function cubicInOut(t : Float) : Float
		return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0;

	// --- quart ---

	public static inline function quartIn(t : Float) : Float
		return t * t * t * t;

	public static inline function quartOut(t : Float) : Float
	{
		var u = t - 1.0;
		return 1.0 - u * u * u * u;
	}

	public static inline function quartInOut(t : Float) : Float
	{
		var u = t - 1.0;
		return t < 0.5 ? 8.0 * t * t * t * t : 1.0 - 8.0 * u * u * u * u;
	}

	// --- quint ---

	public static inline function quintIn(t : Float) : Float
		return t * t * t * t * t;

	public static inline function quintOut(t : Float) : Float
	{
		var u = t - 1.0;
		return 1.0 + u * u * u * u * u;
	}

	public static inline function quintInOut(t : Float) : Float
	{
		var u = t - 1.0;
		return t < 0.5 ? 16.0 * t * t * t * t * t : 1.0 + 16.0 * u * u * u * u * u;
	}

	// --- sine ---

	public static inline function sineIn(t : Float) : Float
		return 1.0 - Math.cos(t * Math.PI * 0.5);

	public static inline function sineOut(t : Float) : Float
		return Math.sin(t * Math.PI * 0.5);

	public static inline function sineInOut(t : Float) : Float
		return -(Math.cos(Math.PI * t) - 1.0) * 0.5;

	// --- circ ---

	public static inline function circIn(t : Float) : Float
		return 1.0 - Math.sqrt(1.0 - t * t);

	public static inline function circOut(t : Float) : Float
		return Math.sqrt(1.0 - (t - 1.0) * (t - 1.0));

	public static inline function circInOut(t : Float) : Float
		return t < 0.5 ? (1.0 - Math.sqrt(1.0 - 4.0 * t * t)) * 0.5 : (Math.sqrt(1.0 - (-2.0 * t + 2.0) * (-2.0 * t + 2.0)) + 1.0) * 0.5;

	// --- expo ---

	public static function expoIn(t : Float) : Float
		return t == 0.0 ? 0.0 : Math.pow(2.0, 10.0 * t - 10.0);

	public static function expoOut(t : Float) : Float
		return t == 1.0 ? 1.0 : 1.0 - Math.pow(2.0, -10.0 * t);

	public static function expoInOut(t : Float) : Float
	{
		if (t == 0.0) return 0.0;
		if (t == 1.0) return 1.0;
		return t < 0.5 ? Math.pow(2.0, 20.0 * t - 10.0) * 0.5 : (2.0 - Math.pow(2.0, -20.0 * t + 10.0)) * 0.5;
	}

	// --- back (overshoot) ---

	public static function backIn(t : Float) : Float
	{
		var s = 1.70158;
		return t * t * ((s + 1.0) * t - s);
	}

	public static function backOut(t : Float) : Float
	{
		var u = t - 1.0;
		var s = 1.70158;
		return u * u * ((s + 1.0) * u + s) + 1.0;
	}

	public static function backInOut(t : Float) : Float
	{
		var s = 1.70158 * 1.525;
		var t2 = t * 2.0;
		if (t2 < 1.0) return 0.5 * (t2 * t2 * ((s + 1.0) * t2 - s));
		var u = t2 - 2.0;
		return 0.5 * (u * u * ((s + 1.0) * u + s) + 2.0);
	}

	// --- elastic ---

	public static function elasticIn(t : Float) : Float
	{
		if (t == 0.0 || t == 1.0) return t;
		var p = 0.3;
		var s = p * 0.25;
		var u = t - 1.0;
		return -(Math.pow(2.0, 10.0 * u) * Math.sin((u - s) * (2.0 * Math.PI) / p));
	}

	public static function elasticOut(t : Float) : Float
	{
		if (t == 0.0 || t == 1.0) return t;
		var p = 0.3;
		var s = p * 0.25;
		return Math.pow(2.0, -10.0 * t) * Math.sin((t - s) * (2.0 * Math.PI) / p) + 1.0;
	}

	public static function elasticInOut(t : Float) : Float
	{
		if (t == 0.0 || t == 1.0) return t;
		var p = 0.45;
		var s = p * 0.25;
		var t2 = t * 2.0;
		var u = t2 - 1.0;
		if (t2 < 1.0)
			return -0.5 * (Math.pow(2.0, 10.0 * u) * Math.sin((u - s) * (2.0 * Math.PI) / p));
		return Math.pow(2.0, -10.0 * u) * Math.sin((u - s) * (2.0 * Math.PI) / p) * 0.5 + 1.0;
	}

	// --- bounce ---

	public static function bounceOut(t : Float) : Float
	{
		if (t < 1.0 / 2.75)
			return 7.5625 * t * t;
		else if (t < 2.0 / 2.75)
		{
			t -= 1.5 / 2.75;
			return 7.5625 * t * t + 0.75;
		}
		else if (t < 2.5 / 2.75)
		{
			t -= 2.25 / 2.75;
			return 7.5625 * t * t + 0.9375;
		}
		else
		{
			t -= 2.625 / 2.75;
			return 7.5625 * t * t + 0.984375;
		}
	}

	public static inline function bounceIn(t : Float) : Float
		return 1.0 - bounceOut(1.0 - t);

	public static function bounceInOut(t : Float) : Float
		return t < 0.5 ? (1.0 - bounceOut(1.0 - 2.0 * t)) * 0.5 : bounceOut(2.0 * t - 1.0) * 0.5 + 0.5;
}
