package extract.views.lobby;

import h2d.Object;
import extract.design.PlayDesign;
import extract.views.SubView;

class PlaySubView extends SubView
{
	public function new(?parent : Object)
	{
		super(parent);
		design = new PlayDesign();
	}
}