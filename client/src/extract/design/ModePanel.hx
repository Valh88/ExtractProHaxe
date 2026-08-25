package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/**
	Left-side "GAME MODE" panel, built from the Lunacy `PanelBG` frame
	(300x460, gold border #C8956C, fill #1A1208).
**/
@:uiComp("mode-panel")
class ModePanel extends Flow implements Object
{
	static var SRC =
		<mode-panel>
			<flow class="mode-inner" x="2" y="2">
				<text id="title" class="mode-title" x="106" y="15"/>
				<flow class="map-image" x="60" y="55"/>
				<text id="dur" class="duration" x="134" y="185"/>
				<flow class="mode-icons" x="85" y="215">
					<flow class="solo-icon" x="0" y="0">
						<text id="solo" class="solo-label" x="48" y="0"/>
					</flow>
					<flow class="party-icon" x="74" y="0">
						<text id="party" class="party-label" x="45" y="0"/>
					</flow>
				</flow>
				<flow class="search-btn" x="60" y="290">
					<text id="search" class="search-text" x="60" y="12"/>
				</flow>
			</flow>
		</mode-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		title.text = "GAME MODE";
		dur.text = "30:00";
		solo.text = "1";
		party.text = "3";
		search.text = "SEARCH";
	}
}
