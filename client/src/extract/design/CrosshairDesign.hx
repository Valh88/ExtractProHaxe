package extract.design;

import h2d.Graphics;
import h2d.Object;
import shared.GameData;

class CrosshairDesign extends Object
{
	var barTop : Graphics;
	var barBottom : Graphics;
	var barLeft : Graphics;
	var barRight : Graphics;

	var barWidth : Float;
	var barLength : Float;
	var baseSpread : Float;
	var moveSpreadAmt : Float;
	var shootSpreadAmt : Float;
	var recoverySpeed : Float;

	/** Current interpolated spread from center. */
	public var spread(default, null) : Float = 0;
	/** Target spread: baseSpread + movement + shoot additives. */
	var targetSpread : Float = 0;
	var moving : Bool = false;
	var shootTimer : Float = 0;

	/** Light green, semi-transparent (ARGB). */
	static inline var BAR_COLOR : Int = 0xCC66FF66;

	public function new(?parent : Object, gd : GameData)
	{
		super(parent);

		barWidth = gd.req("Crosshair", "barWidth");
		barLength = gd.req("Crosshair", "barLength");
		baseSpread = gd.req("Crosshair", "baseSpread");
		moveSpreadAmt = gd.req("Crosshair", "moveSpread");
		shootSpreadAmt = gd.req("Crosshair", "shootSpread");
		recoverySpeed = gd.req("Crosshair", "recoverySpeed");

		spread = baseSpread;
		targetSpread = baseSpread;

		barTop = new Graphics(this);
		barTop.beginFill(BAR_COLOR);
		barTop.drawRect(-barWidth * 0.5, -barLength, barWidth, barLength);
		barTop.endFill();

		barBottom = new Graphics(this);
		barBottom.beginFill(BAR_COLOR);
		barBottom.drawRect(-barWidth * 0.5, 0, barWidth, barLength);
		barBottom.endFill();

		barLeft = new Graphics(this);
		barLeft.beginFill(BAR_COLOR);
		barLeft.drawRect(-barLength, -barWidth * 0.5, barLength, barWidth);
		barLeft.endFill();

		barRight = new Graphics(this);
		barRight.beginFill(BAR_COLOR);
		barRight.drawRect(0, -barWidth * 0.5, barLength, barWidth);
		barRight.endFill();

		barTop.y = -spread;
		barBottom.y = spread;
		barLeft.x = -spread;
		barRight.x = spread;
	}

	/** Call each frame — exponential ease toward target + apply bar positions. */
	public function update(dt : Float) : Void
	{
		if (shootTimer > 0)
			shootTimer = Math.max(0, shootTimer - dt);

		targetSpread = baseSpread
			+ (moving ? moveSpreadAmt : 0)
			+ (shootTimer > 0 ? shootSpreadAmt : 0);

		applySpread(dt);
	}

	/** Set movement spread. */
	public function setMovement(v : Bool) : Void
	{
		moving = v;
	}

	/** Trigger shoot spread (auto-decays). */
	public function shoot() : Void
	{
		shootTimer = 0.2;
	}

	/** Interpolate spread toward target and position bars. */
	function applySpread(dt : Float) : Void
	{
		spread += (targetSpread - spread) * (1.0 - Math.exp(-recoverySpeed * dt));
		barTop.y = -spread;
		barBottom.y = spread;
		barLeft.x = -spread;
		barRight.x = spread;
	}
}
