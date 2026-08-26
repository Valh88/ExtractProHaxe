package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("play-view")
class PlayDesign extends Flow implements Object
{
	static var SRC =
		<play-view class="play-view">
			<mode-panel id="modePanel" x="40" y="280"/>
		</play-view>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
	}
}
