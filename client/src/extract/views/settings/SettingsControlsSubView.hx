package extract.views.settings;

import extract.design.SettingsControlsContent;
import extract.utils.SubView;
import shared.events.EventBus;

class SettingsControlsSubView extends SubView<SettingsControlsContent>
{
	public function new(bus : EventBus)
	{
		super(bus, new SettingsControlsContent());
	}
}
