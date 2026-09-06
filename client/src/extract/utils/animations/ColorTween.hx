package extract.utils.animations;

/**
	Tweens a color (RGBA) on an `h2d.Drawable` via its `color` property
	(`h3d.Vector4`, channels 0..1). Also supports tinting an `h2d.Object`
	that has a `color` field.

	Usage:
	  new ColorTween(obj, 0xFF0000FF, 0x00FF00FF, 1.0, Easing.linear).start();
	  // or with Vector4:
	  new ColorTween.fromVector4(obj, red, blue, 1.0).start();
**/
class ColorTween extends AAnimation
{
	var fromR : Float;
	var fromG : Float;
	var fromB : Float;
	var fromA : Float;
	var toR : Float;
	var toG : Float;
	var toB : Float;
	var toA : Float;

	/**
		@param target   h2d.Object with a `color` field (h3d.Vector4)
		@param from     start color as ARGB Int (0xAARRGGBB)
		@param to       end color as ARGB Int (0xAARRGGBB)
		@param duration seconds
		@param easing   easing function (null → linear)
	**/
	public function new(target : h2d.Object, from : Int, to : Int, duration : Float, ?easing : Float -> Float)
	{
		fromR = ((from >> 16) & 0xFF) / 255.0;
		fromG = ((from >> 8) & 0xFF) / 255.0;
		fromB = (from & 0xFF) / 255.0;
		fromA = ((from >> 24) & 0xFF) / 255.0;
		toR = ((to >> 16) & 0xFF) / 255.0;
		toG = ((to >> 8) & 0xFF) / 255.0;
		toB = (to & 0xFF) / 255.0;
		toA = ((to >> 24) & 0xFF) / 255.0;
		super(target, duration, easing);
	}

	override function apply(t : Float) : Void
	{
		var c : h3d.Vector4 = Reflect.field(target, "color");
		if (c == null)
		{
			c = new h3d.Vector4();
			Reflect.setField(target, "color", c);
		}
		c.r = fromR + (toR - fromR) * t;
		c.g = fromG + (toG - fromG) * t;
		c.b = fromB + (toB - fromB) * t;
		c.a = fromA + (toA - fromA) * t;
	}
}
