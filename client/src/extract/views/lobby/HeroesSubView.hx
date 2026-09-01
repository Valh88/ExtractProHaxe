package extract.views.lobby;

import h2d.Object;
import extract.views.SubView;
import shared.events.EventBus;

class HeroesSubView extends SubView
{
	public function new(bus : EventBus, ?parent : Object)
	{
		super(bus, parent);
		trace('view load');
	}
}