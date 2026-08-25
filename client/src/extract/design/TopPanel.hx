package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Top bar: gold amount, menu tabs, party slots and right-side icons. */
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
				<flow class="slot slot-idle" x="0" y="0"/>
				<flow class="slot slot-main" x="45" y="0"/>
				<flow class="slot slot-idle" x="90" y="0"/>
				<flow class="icon" x="135" y="0"/>
				<flow class="icon" x="180" y="0"/>
				<flow class="icon" x="225" y="0"/>
			</flow>
		</top-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		gold.text = "1488";
		tabPlay.text = "PLAY";
		tabInv.text = "INVENTORY";
		tabHero.text = "HEROES";
		tabMkt.text = "MARKET";
	}
}
