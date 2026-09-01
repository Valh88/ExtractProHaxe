package extract.views.lobby;

import extract.design.PlayDesign;
import extract.views.SubViewObject;

class PlaySubView extends SubViewObject
{
	var playDesign : PlayDesign;

	public function new(?parent : Object)
	{
		super(parent);
		playDesign = new PlayDesign();
		design = playDesign;
	}

	public function getPlayDesign() : PlayDesign return playDesign;
}