package extract.views.settings;

import h2d.Object;
import h2d.domkit.Style;
import extract.design.SettingsDesign;
import extract.utils.SubView;
import shared.events.EventBus;

class SettingsOverlay extends SubView<SettingsDesign>
{
	var settings : SettingsDesign;
	var style : Style;

	public function new(bus : EventBus, style : Style, ?parent : Object)
	{
		settings = new SettingsDesign();
		super(bus, settings, parent);
		this.style = style;

		settings.onBack = close;
		settings.onSave = close;
	}

	public function open() : Void { design.visible = true; }
	public function close() : Void { design.visible = false; }
	public function toggle() : Void { design.visible = !design.visible; }
}
