package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

@:uiComp("hud-design")
class HudDesign extends Flow implements Object
{
	static var SRC =
		<hud-design class="hud-root">
			<flow id="skillsPanel" class="skills-panel" x="772" y="864">
				<flow id="skill0" class="skill-slot" x="0" y="0"/>
				<flow id="skill1" class="skill-slot" x="64" y="0"/>
				<flow id="skill2" class="skill-slot" x="128" y="0"/>
				<flow id="skill3" class="skill-slot" x="192" y="0"/>
				<flow id="skill4" class="skill-slot" x="256" y="0"/>
				<flow id="skill5" class="skill-slot" x="320" y="0"/>
			</flow>
			<flow id="stanceIndicator" class="stance-indicator" x="290" y="962"/>
			<flow id="hpBg" class="hp-bg" x="810" y="966">
				<flow id="hpFill" class="hp-fill" x="0" y="0"/>
			</flow>
			<flow id="energyBg" class="energy-bg" x="810" y="1010">
				<flow id="energyFill" class="energy-fill" x="0" y="0"/>
			</flow>
			<flow id="statsPanel" class="statistic-root" x="20" y="20">
				<text id="fpsCaption" class="stat-caption" x="0" y="0"/>
				<text id="fpsValue" class="stat-value" x="50" y="0"/>
				<text id="pingCaption" class="stat-caption" x="0" y="22"/>
				<text id="pingValue" class="stat-value" x="50" y="22"/>
			</flow>
		</hud-design>;

	public var crosshair(default, set) : CrosshairDesign;

	function set_crosshair(v : CrosshairDesign) : CrosshairDesign
	{
		return crosshair = v;
	}

	public function new(?parent)
	{
		super(parent);
		initComponent();

		addRoundedChild(skill0, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(skill1, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(skill2, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(skill3, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(skill4, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(skill5, 56, 56, 6, 0x0F0F0F, 0xE0D080);
		addRoundedChild(stanceIndicator, 58, 58, 8, 0x0F0F0F, 0xE0D080);

		fpsCaption.text = "Fps:";
		fpsValue.text = "0";
		pingCaption.text = "Ping:";
		pingValue.text = "0";
	}

	public function setFps(v : Int) : Void
	{
		fpsValue.text = Std.string(v);
	}

	public function setPing(v : Int) : Void
	{
		pingValue.text = Std.string(v);
	}

	function addRoundedChild(parent : Flow, w : Int, h : Int, r : Int, fill : Int, border : Int)
	{
		// one baked tile: opaque border rim + semi-transparent fill inside,
		// used as ScaleGrid background so it never layers above/below children
		parent.backgroundTile = getSlotTile(w, h, r, fill, border);
		parent.borderWidth = r;
		parent.borderHeight = r;
	}

	static var slotTiles : Map<String, h2d.Tile> = new Map();

	function getSlotTile(w : Int, h : Int, r : Int, fill : Int, border : Int) : h2d.Tile
	{
		var key = w + "x" + h + "r" + r;
		var t = slotTiles.get(key);
		if (t != null) return t;

		var rx = (border >> 16) & 0xFF;
		var gx = (border >> 8) & 0xFF;
		var bx = border & 0xFF;
		var fx = (fill >> 16) & 0xFF;
		var fy = (fill >> 8) & 0xFF;
		var fz = fill & 0xFF;

		var pix = hxd.Pixels.alloc(w, h, RGBA);
		for (y in 0...h)
			for (x in 0...w)
			{
				var px = x + 0.5, py = y + 0.5;
				var a : Int;
				var cr = 0, cg = 0, cb = 0;
				if (inRoundedRect(px, py, 0, 0, w, h, r))
				{
					if (inRoundedRect(px, py, 2, 2, w - 4, h - 4, Math.max(1, r - 2)))
					{
						// semi-transparent fill (0x66 = 40%)
						a = 0x66;
						cr = fx; cg = fy; cb = fz;
					}
					else
					{
						a = 0xFF;
						cr = rx; cg = gx; cb = bx;
					}
				}
				else
					a = 0;
				pix.setPixel(x, y, (a << 24) | (cr << 16) | (cg << 8) | cb);
			}

		var tex = h3d.mat.Texture.fromPixels(pix);
		tex.filter = Linear;
		t = h2d.Tile.fromTexture(tex);
		slotTiles.set(key, t);
		return t;
	}

	static function inRoundedRect(px : Float, py : Float, x0 : Float, y0 : Float, w : Float, h : Float, r : Float) : Bool
	{
		var cx = x0 + r < px ? (px < x0 + w - r ? px : x0 + w - r) : x0 + r;
		var cy = y0 + r < py ? (py < y0 + h - r ? py : y0 + h - r) : y0 + r;
		var dx = px - cx, dy = py - cy;
		return dx * dx + dy * dy <= r * r;
	}
}
