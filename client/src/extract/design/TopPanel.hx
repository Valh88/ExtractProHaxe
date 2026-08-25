package extract.design;

import h2d.Flow;
import h2d.Graphics;
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
			<flow class="menu-tabs" x="776" y="13">
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
