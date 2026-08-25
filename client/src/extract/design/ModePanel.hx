package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Left-hand "GAME MODE" panel: title, map preview, duration, mode icons, search. */
@:uiComp("mode-panel")
class ModePanel extends Flow implements Object
{
	static var SRC =
		<mode-panel>
			<text id="title" class="mode-title" x="106" y="15"/>
			<flow class="map-image" x="60" y="55"/>
			<text id="dur" class="duration" x="134" y="185"/>
			<mode-icon class="mode-icon-solo" label={"1"} x="85" y="215"/>
			<mode-icon class="mode-icon-party" label={"3"} x="159" y="215"/>
			<search-button x="60" y="290"/>
		</mode-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		title.text = "GAME MODE";
		dur.text = "30:00";
	}
}
