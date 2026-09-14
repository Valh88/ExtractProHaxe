package extract.utils.ui;

/**
	Reusable menu tab strip (self-contained, no domkit/CSS dependency).

	Draws one tab per key into a caller-provided container `Flow`:
	centered label text, active underline, active background and a hit zone.
	All visuals are code-drawn so the component works anywhere; the caller
	provides the font, slot width and optional per-key labels/color scheme.

	Usage:
		var bar = new TabBar<MyTab>(tabsWrap, [A, B, C], 130, font);
		bar.onSelect = tabView.switchToAnimated;
		bar.select(A);
**/
class TabBar<K : EnumValue>
{
	/** Currently selected key. */
	public var current(default, null) : Null<K>;

	/** Fired when the user clicks a tab. */
	public var onSelect : Null<K -> Void>;

	/** Width of one tab slot (hit area + horizontal spacing). */
	public var slotWidth : Float;

	/** Height of the whole strip (labels + hit areas). */
	public var barHeight : Float;

	/** Horizontal inset of the underline relative to the slot. */
	public var underlineInset : Float = 10;

	/** Active label color. */
	public var activeColor : Int = 0xFFF0D0;

	/** Idle label color. */
	public var idleColor : Int = 0x80786E;

	/** Active underline color. */
	public var underlineColor : Int = 0xC4A44A;

	/** Active tab background fill color. */
	public var bgColor : Int = 0x241C14;

	/** Active tab background alpha. */
	public var bgAlpha : Float = 1;

	/** The strip container (filled with the tab elements). */
	public var container(default, null) : h2d.Flow;

	var keys : Array<K>;
	var items : Array<TabBarItem>;

	public function new(container : h2d.Flow, keys : Array<K>, slotWidth : Float,
			font : h2d.Font, ?labelOf : K -> String, ?barHeight : Float = 34)
	{
		this.container = container;
		this.keys = keys;
		this.slotWidth = slotWidth;
		this.barHeight = barHeight;
		items = [];
		for (i in 0...keys.length)
		{
			var label = labelOf != null ? labelOf(keys[i]) : Std.string(keys[i]);
			items.push(makeItem(i, label, font));
		}
	}

	/** Set the active tab (visual highlight only; no onSelect). */
	public function setActive(key : K) : Void
	{
		for (i in 0...items.length)
		{
			var it = items[i];
			var active = keys[i] == key;
			it.text.textColor = active ? activeColor : idleColor;
			it.line.scaleX = active ? 1 : 0;
			it.bg.visible = active;
		}
	}

	/** Select a tab: highlight + fire onSelect. No-op for the current tab. */
	public function select(key : K) : Void
	{
		if (current == key) return;
		current = key;
		setActive(key);
		if (onSelect != null) onSelect(key);
	}

	// --- internal ---

	function makeItem(idx : Int, label : String, font : h2d.Font) : TabBarItem
	{
		var x = slotWidth * idx;

		var it = new TabBarItem();
		it.bg = new h2d.Graphics();
		it.bg.beginFill(bgColor, bgAlpha);
		it.bg.drawRoundedRect(0, 0, slotWidth, barHeight, 4);
		it.bg.endFill();
		it.bg.setPosition(x, 0);
		it.bg.visible = false;
		container.addChildAt(it.bg, 0);
		container.getProperties(it.bg).isAbsolute = true;

		it.text = new h2d.Text(font);
		it.text.text = label;
		it.text.textColor = idleColor;
		var tx = x + (slotWidth - it.text.textWidth) * 0.5;
		var ty = (barHeight - font.lineHeight) * 0.5;
		it.text.setPosition(tx, ty);
		container.addChild(it.text);
		container.getProperties(it.text).isAbsolute = true;

		it.line = new h2d.Graphics();
		it.line.beginFill(underlineColor);
		it.line.drawRect(0, 0, slotWidth - underlineInset * 2, 2);
		it.line.endFill();
		it.line.setPosition(x + underlineInset, barHeight - 2);
		it.line.scaleX = 0;
		container.addChild(it.line);
		container.getProperties(it.line).isAbsolute = true;

		var hit = new h2d.Interactive(slotWidth, barHeight, container);
		hit.setPosition(x, 0);
		hit.cursor = Button;
		container.getProperties(hit).isAbsolute = true;
		hit.onClick = function(_) select(keys[idx]);

		return it;
	}
}

/** Per-tab visual parts. */
class TabBarItem
{
	public var text : h2d.Text;
	public var bg : h2d.Graphics;
	public var line : h2d.Graphics;

	public function new() {}
}