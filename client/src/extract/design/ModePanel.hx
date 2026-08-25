package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

@:uiComp("mode-panel")
class ModePanel extends Flow implements Object
{
	static var SRC =
		<mode-panel>
			<flow class="mode-inner" x="2" y="2">
				<flow id="titleWrap" class="title-wrap" x="0" y="15">
					<text id="title" class="mode-title"/>
				</flow>
				<flow id="mapImage" class="map-image" x="60" y="55"/>
				<flow id="durWrap" class="dur-wrap" x="60" y="185">
					<text id="dur" class="duration"/>
				</flow>
				<flow class="mode-icons" x="85" y="215">
					<flow id="soloIcon" class="solo-icon" x="0" y="0">
						<text id="solo" class="solo-label" x="48" y="0"/>
					</flow>
					<flow id="partyIcon" class="party-icon" x="74" y="0">
						<text id="party" class="party-label" x="45" y="0"/>
					</flow>
				</flow>
				<flow id="searchBtn" class="search-btn" x="60" y="290">
					<flow id="searchWrap" class="search-wrap" x="0" y="0">
						<text id="search" class="search-text"/>
					</flow>
				</flow>
			</flow>
		</mode-panel>;

	var panelBg : Graphics;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		panelBg = new Graphics();
		this.addChildAt(panelBg, 0);
		drawPanelBg();

		addRoundedChild(mapImage, 180, 120, 4, 0x2A1A10, 0x3A2A18);
		addRoundedChild(soloIcon, 56, 56, 6, 0x2A1A10, 0xC8956C);
		addRoundedChild(partyIcon, 56, 56, 6, 0x1A1208, 0x3A2A18);
		addRoundedChild(searchBtn, 180, 50, 4, 0x8B2010, 0xA03020);

		titleWrap.horizontalAlign = Middle;
		durWrap.horizontalAlign = Middle;
		searchWrap.horizontalAlign = Middle;
		searchWrap.verticalAlign = Middle;

		title.text = "GAME MODE";
		dur.text = "30:00";
		solo.text = "1";
		party.text = "3";
		search.text = "SEARCH";
	}

	function drawPanelBg()
	{
		panelBg.clear();
		panelBg.beginFill(0xC8956C);
		panelBg.drawRoundedRect(0, 0, 300, 460, 6);
		panelBg.endFill();
		panelBg.beginFill(0x1A1208);
		panelBg.drawRoundedRect(2, 2, 296, 456, 4);
		panelBg.endFill();
	}

	function addRoundedChild(parent : Flow, w : Int, h : Int, r : Int, fill : Int, border : Int)
	{
		var g = new Graphics();
		parent.addChildAt(g, 0);
		g.beginFill(border);
		g.drawRoundedRect(0, 0, w, h, r);
		g.endFill();
		g.beginFill(fill);
		g.drawRoundedRect(2, 2, w - 4, h - 4, Std.int(Math.max(0, r - 2)));
		g.endFill();
	}
}
