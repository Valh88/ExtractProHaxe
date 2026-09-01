package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Placeholder heroes sub-view design (empty root for now). */
@:uiComp("heroes-view")
class HeroesDesign extends Flow implements Object
{
	static var SRC =
		<heroes-view class="heroes-view"/>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
	}
}