package extract.views.settings;

import extract.design.SettingsAudioContent;
import extract.utils.SubView;
import shared.events.EventBus;

class SettingsAudioSubView extends SubView<SettingsAudioContent>
{
	public function new(bus : EventBus)
	{
		super(bus, new SettingsAudioContent());
	}
}
