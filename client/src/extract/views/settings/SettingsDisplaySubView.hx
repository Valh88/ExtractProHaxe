package extract.views.settings;

import extract.design.SettingsDisplayContent;
import extract.utils.SubView;
import shared.events.EventBus;

class SettingsDisplaySubView extends SubView<SettingsDisplayContent>
{
	public function new(bus : EventBus)
	{
		super(bus, new SettingsDisplayContent());
	}
}
