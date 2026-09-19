package extract.controllers;

import extract.gfx.DistanceFog;
import h3d.Vector;

/** Time-of-day phase. `Day`/`Night` are the monotone halves of the cycle;
    `Sunset`/`Sunrise` are the two twilight crossings of the horizon
    (distinguished by whether the sun is descending or climbing). */
enum DayPhase
{
	Day;
	Sunset;
	Sunrise;
	Night;
}

/** Drives the scene's day/night look from the sun's elevation.

    Plain presentation helper (NOT a System — it runs inside SunSystem which
    already owns the light, so there is no event-bus round trip). Each frame
    {@link apply} recomputes the current {@link phase} from the sun direction
    and smoothly interpolates every light-facing setting toward that phase:

    - engine background color (the clear color the engine fills the frame with)
    - distance-fog color (in practice the visible "sky" tint — fog covers all
      far pixels, including the horizon)
    - sun light power and color (day: bright white; twilight: warm; night: a
      faint cool "moon" fill)

    Transitions are elevation-driven (smoothstep over a band around the
    horizon), so there are NO hard state jumps, and sunrise/sunset share the
    same warm palette — they only differ in the reported {@link phase}.

    Config lives in the static vars below (project convention for visual
    knobs, matching `SunSystem.SUN_MAX_ELEV` etc.). */
class DayNightController
{
	/** Background (clear) colors per phase main color. */
	public static var DAY_BG : Int = 0x87CEEB;
	public static var SUNSET_BG : Int = 0xC4622A;
	public static var NIGHT_BG : Int = 0x050810;
	/** Distance-fog colors per phase (the actual visible "sky"). */
	public static var DAY_FOG : Int = 0x8FA3B5;
	public static var SUNSET_FOG : Int = 0xB08050;
	public static var NIGHT_FOG : Int = 0x101820;
	/** 0..1 — how dark the night is. 1 = near-black (nothing visible),
	    0.85 = dark but silhouettes readable, 0 = only the night palette
	    (lunar fill still lit). Drives background, fog AND the sun light. */
	public static var NIGHT_DARKNESS : Float = 1.0;
	/** Sun light intensity per phase. */
	public static var DAY_POWER : Float = 2.0;
	public static var SUNSET_POWER : Float = 0.7;
	public static var NIGHT_POWER : Float = 0.05;
	/** Sun light tint per phase. */
	public static var DAY_COLOR : Vector = new Vector(1.0, 0.97, 0.92);
	public static var SUNSET_COLOR : Vector = new Vector(1.0, 0.62, 0.30);
	public static var NIGHT_COLOR : Vector = new Vector(0.12, 0.16, 0.35);
	/** Renderer environment (IBL) strength per phase. Heaps PBR keeps an
	    environment map on the renderer (`Environment.getDefault()`) and shades
	    every surface with it unconditionally — that is the flat ambient glow
	    that stays even when the sun power hits 0. It MUST dim with night or
	    "dark" never becomes dark. 1.0 = default env at full strength. */
	public static var DAY_ENV_POWER : Float = 1.0;
	public static var NIGHT_ENV_POWER : Float = 0.0;

	/** Elevation (sunDir.y) band in which twilight is active. */
	public static var TWILIGHT_ELEV : Float = 0.02;

	var light : h3d.scene.pbr.DirLight;
	var fog : Null<DistanceFog>;
	var scene : h3d.scene.Scene;
	var envPowerBase : Float = 1.0;
	var envBaseCaptured : Null<Float> = null;

	/** Current time-of-day phase (updated every {@link apply} call). */
	public var phase(default, null) : DayPhase = Day;

	public function new(light : h3d.scene.pbr.DirLight, ?fog : DistanceFog, scene : h3d.scene.Scene)
	{
		this.light = light;
		this.fog = fog;
		this.scene = scene;
	}

	/** Recompute the phase from the sun and push all light-facing settings.
	    `sunDir` is the unit vector FROM the camera TOWARD the sun (its `.y` is
	    the elevation sine); `sunAngle` breaks the twilight tie between sunset
	    (descending, < π) and sunrise (climbing, > π). */
	public function apply(sunDir : Vector, sunAngle : Float)
	{
		var y = sunDir.y;
		phase = computePhase(y, sunAngle);

		var e = TWILIGHT_ELEV;
		// 1 in full day, 0 in full night; smooth inside the horizon band
		var dayT = smoothstep(-e, e, y);
		// 1 right AT the horizon, 0 in deep day/night — drives the warm tint
		var warm = (1.0 - dayT) * smoothstep(-e, 0.0, y);
		// darkness floor: only weights in night, pulls the palette to black
		var dark = (1.0 - dayT) * NIGHT_DARKNESS;

		var bg = lerpInt(NIGHT_BG, DAY_BG, dayT);
		bg = lerpInt(bg, SUNSET_BG, warm);
		bg = lerpInt(bg, 0x000000, dark);
		h3d.Engine.getCurrent().backgroundColor = bg;

		if (fog != null)
		{
			var fc = lerpInt(NIGHT_FOG, DAY_FOG, dayT);
			fc = lerpInt(fc, SUNSET_FOG, warm);
			fc = lerpInt(fc, 0x000000, dark);
			fog.setColor(fc);
		}

		light.power = lerp(NIGHT_POWER, DAY_POWER, dayT) * (1.0 - dark);
		var c = lerpVec(NIGHT_COLOR, DAY_COLOR, dayT);
		c = lerpVec(c, SUNSET_COLOR, warm);
		light.color.set(c.x, c.y, c.z);

		// dim the renderer's indirect (IBL/env) light with the same envelope —
		// heaps PBR keeps a default environment map around and shades every
		// surface with it even when the direct sun light is off; without this
		// the scene never goes black no matter how dark the palette gets
		var pbr = Std.downcast(scene.renderer, h3d.scene.pbr.Renderer);
		if (pbr != null && pbr.env != null)
		{
			// capture the user/env base strength once (the default env is 1.0,
			// but another scene may swap in a custom env) — the per-frame value
			// then only scales, never clamps, that base
			if (envBaseCaptured == null)
			{
				envBaseCaptured = pbr.env.power;
				envPowerBase = envBaseCaptured;
			}
			var envPower = envPowerBase * lerp(NIGHT_ENV_POWER, DAY_ENV_POWER, dayT);
			pbr.env.power = envPower;
		}
	}

	static function computePhase(y : Float, sunAngle : Float) : DayPhase
	{
		var e = TWILIGHT_ELEV;
		if (y >= e) return Day;
		if (y <= -e) return Night;
		return sunAngle < Math.PI ? Sunset : Sunrise;
	}

	static function smoothstep(e0 : Float, e1 : Float, x : Float) : Float
	{
		var t = hxd.Math.clamp((x - e0) / (e1 - e0), 0.0, 1.0);
		return t * t * (3.0 - 2.0 * t);
	}

	static function lerp(a : Float, b : Float, t : Float) : Float
	{
		return a + (b - a) * t;
	}

	static function lerpInt(a : Int, b : Int, t : Float) : Int
	{
		var ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
		var br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
		var r = Std.int(ar + (br - ar) * t);
		var g = Std.int(ag + (bg - ag) * t);
		var bl = Std.int(ab + (bb - ab) * t);
		return (r << 16) | (g << 8) | bl;
	}

	static function lerpVec(a : Vector, b : Vector, t : Float) : Vector
	{
		return new Vector(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
	}
}