package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Bottom bar with a fading gradient (approximated as a semi-transparent strip). */
@:uiComp("bottom-panel")
class BottomPanel extends Flow implements Object
{
	static var SRC =
		<bottom-panel>
			<flow class="bottom-gradient" x="0" y="0"/>
		</bottom-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
	}
}
