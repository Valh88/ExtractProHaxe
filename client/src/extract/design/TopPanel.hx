package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.Interactive;
import h2d.domkit.Object;

@:uiComp("top-panel")
class TopPanel extends Flow implements Object
{
	static var SRC =
		<top-panel>
			<flow class="top-border" x="0" y="68"/>
			<flow class="gold-group" x="55" y="13">
				<flow class="gold-icon"/>
				<text id="gold" class="gold-amount" x="36" y="0"/>
			</flow>
			<flow id="menuTabs" class="menu-tabs" x="776" y="13">
				<text id="tabPlay" class="tab tab-active" x="0" y="0"/>
				<text id="tabInv" class="tab tab-idle" x="75" y="0"/>
				<text id="tabHero" class="tab tab-idle" x="201" y="0"/>
				<text id="tabMkt" class="tab tab-idle" x="299" y="0"/>
			</flow>
			<flow class="right-icons" x="1632" y="13">
				<flow id="slot1" class="slot slot-idle" x="0" y="0"/>
				<flow id="slotMain" class="slot slot-main" x="45" y="0"/>
				<flow id="slot2" class="slot slot-idle" x="90" y="0"/>
				<flow id="iconChat" class="icon" x="135" y="0"/>
				<flow id="iconSettings" class="icon" x="180" y="0"/>
				<flow id="iconExit" class="icon" x="225" y="0"/>
			</flow>
		</top-panel>;

	/** Set by the root view; fired on tab click (0=Play, 1=Inv, 2=Heroes, 3=Market). */
	public var onTabSelected : Null<Int -> Void>;

	// tab text order matches click zone indices
	var tabTexts : Array<h2d.Text>;
	/** Set by the scene BEFORE design creation — shared scene animCtrl. */
	public static var animCtrl : extract.utils.animations.AnimationController;

	static inline var HOVER_COLOR : Int = 0xFFFFFFFF;
	static inline var IDLE_COLOR : Int = 0xFF737373;
	static inline var ACTIVE_COLOR : Int = 0xFFBFBFBF;
	static inline var HOVER_DURATION : Float = 0.15;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		drawSlot(slot1, 0x2A2A2A, 0x404040);
		drawSlot(slotMain, 0x3A2A1A, 0xC8956C);
		drawSlot(slot2, 0x2A2A2A, 0x404040);
		drawIcon(iconChat);
		drawIcon(iconSettings);
		drawIcon(iconExit);

		gold.text = "1488";
		tabPlay.text = "PLAY";
		tabInv.text = "INVENTORY";
		tabHero.text = "HEROES";
		tabMkt.text = "MARKET";

		tabTexts = [tabPlay, tabInv, tabHero, tabMkt];
		addTabHitboxes();
	}

	/** Invisible click zones over the tab texts (design coords). */
	function addTabHitboxes() : Void
	{
		var zones = [ { x : 0, w : 75 }, { x : 75, w : 126 }, { x : 201, w : 98 }, { x : 299, w : 100 } ];
		for (i in 0...zones.length)
		{
			var idx = i;
			var hit = new Interactive(zones[i].w, 30, menuTabs);
			hit.setPosition(zones[i].x, 0);
			hit.cursor = Button;
			menuTabs.getProperties(hit).isAbsolute = true;
			hit.onClick = function(_) if (onTabSelected != null) onTabSelected(idx);
			hit.onOver = function(_) tweenTabColor(idx, HOVER_COLOR);
			hit.onOut = function(_) tweenTabColor(idx, tabTexts[idx].dom.hasClass("tab-active") ? ACTIVE_COLOR : IDLE_COLOR);
		}
	}

	function tweenTabColor(idx : Int, to : Int) : Void
	{
		var txt = tabTexts[idx];
		animCtrl.cancelByTarget(txt);
		// color is null until first ColorTween sets it — use CSS class default
		var from = txt.color != null ? argbToInt(txt.color) : (txt.dom.hasClass("tab-active") ? ACTIVE_COLOR : IDLE_COLOR);
		if (from == to) return;
		animCtrl.add(new extract.utils.animations.ColorTween(txt, from, to, HOVER_DURATION, extract.utils.animations.Easing.quadOut));
	}

	static inline function argbToInt(c : h3d.Vector4) : Int
	{
		if (c == null) return 0xFFFFFFFF;
		var r = Std.int(Math.min(c.r * 255, 255));
		var g = Std.int(Math.min(c.g * 255, 255));
		var b = Std.int(Math.min(c.b * 255, 255));
		var a = Std.int(Math.min(c.a * 255, 255));
		return (a << 24) | (r << 16) | (g << 8) | b;
	}

	/** Highlight the selected tab (moves tab-active / tab-idle classes). */
	public function setActiveTab(i : Int) : Void
	{
		for (t in 0...tabTexts.length)
		{
			var txt = tabTexts[t];
			var active = t == i;
			txt.dom.removeClass("tab-active");
			txt.dom.removeClass("tab-idle");
			txt.dom.addClass(active ? "tab-active" : "tab-idle");
		}
	}

	function drawSlot(parent : Flow, fill : Int, border : Int)
	{
		var g = new Graphics();
		parent.addChildAt(g, 0);
		g.beginFill(border);
		g.drawRoundedRect(0, 0, 40, 40, 4);
		g.endFill();
		g.beginFill(fill);
		g.drawRoundedRect(1, 1, 38, 38, 3);
		g.endFill();
	}

	function drawIcon(parent : Flow)
	{
		var g = new Graphics();
		parent.addChildAt(g, 0);
		g.beginFill(0x404040);
		g.drawRoundedRect(0, 0, 40, 40, 8);
		g.endFill();
	}
}
