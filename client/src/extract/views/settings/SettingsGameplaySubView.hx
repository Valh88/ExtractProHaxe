package extract.views.settings;

import extract.design.SettingsGameplayContent;
import extract.utils.SubView;
import shared.events.EventBus;

class SettingsGameplaySubView extends SubView<SettingsGameplayContent>
{
	public function new(bus : EventBus)
	{
		super(bus, new SettingsGameplayContent());
	}
}
