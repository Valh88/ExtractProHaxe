package extract.views.lobby;

import h2d.Object;
import extract.design.HeroesDesign;
import extract.views.SubView;
import shared.events.EventBus;

class HeroesSubView extends SubView
{
	public function new(bus : EventBus, ?parent : Object)
	{
		super(bus, parent);
		design = new HeroesDesign();
	}
}