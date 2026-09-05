package extract.views.lobby;

import h2d.Object;
import extract.design.HeroesDesign;
import extract.utils.SubView;
import shared.events.EventBus;

class HeroesSubView extends SubView<HeroesDesign>
{
	public function new(bus : EventBus, ?parent : Object)
	{
		super(bus, new HeroesDesign(), parent);
	}
}