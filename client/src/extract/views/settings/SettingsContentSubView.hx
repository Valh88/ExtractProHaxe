package extract.views.settings;

import h2d.Object;
import h2d.Flow;
import extract.utils.SubView;
import shared.events.EventBus;

/** Thin wrapper around any settings content Flow (audio, display, …). */
class SettingsContentSubView extends SubView<Flow>
{
	public function new(bus : EventBus, design : Flow, ?parent : Object)
	{
		super(bus, design, parent);
	}
}
