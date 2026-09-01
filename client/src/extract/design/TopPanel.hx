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
			// fresh local per iteration: closures capture the loop var by reference,
			// without the copy every zone would fire with the LAST index
			var idx = i;
			var hit = new Interactive(zones[i].w, 30, menuTabs);
			hit.setPosition(zones[i].x, 0);
			hit.cursor = Button;
			// raw Interactive added to a Flow participates in its layout —
			// mark absolute (same as CSS position:absolute) to keep manual x/y
			menuTabs.getProperties(hit).isAbsolute = true;
			hit.onClick = function(_) if (onTabSelected != null) onTabSelected(idx);
		}
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
