package extract.views.lobby;

import h2d.Object;
import extract.design.PlayDesign;
import extract.views.SubView;

class PlaySubView extends SubView
{
	var playDesign : PlayDesign;
	
	public function new(?parent : Object)
	{
		super(parent);
		playDesign = new PlayDesign();
		design = playDesign;

		// SEARCH click (owner of this sub-view handles it)
		playDesign.getModePanel().onSearch = onSearchClick;
	}

	function onSearchClick() : Void
	{
		trace("SEARCH clicked");
	}
}