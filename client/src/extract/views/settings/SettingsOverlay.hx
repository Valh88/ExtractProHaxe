package extract.views.settings;

import h2d.Object;
import h2d.domkit.Style;
import extract.design.SettingsDesign;
import extract.design.SettingsAudioContent;
import extract.design.SettingsDisplayContent;
import extract.design.SettingsControlsContent;
import extract.design.SettingsGameplayContent;
import extract.utils.SubView;
import extract.utils.ui.TabView;
import shared.events.EventBus;

class SettingsOverlay extends SubView<SettingsDesign>
{
	var settings : SettingsDesign;
	var style : Style;
	var tabView : TabView<SettingsTab>;

	public function new(bus : EventBus, style : Style, ?parent : Object)
	{
		settings = new SettingsDesign();
		super(bus, settings, parent);
		this.style = style;

		settings.onBack = close;
		settings.onSave = close;

		tabView = new TabView<SettingsTab>(settings.getContentWrap(), style, createSubView);

		settings.onTabClick = function(idx : Int)
			tabView.switchToAnimated(Type.createEnumIndex(SettingsTab, idx));

		tabView.switchTo(SettingsTab.Audio);
	}

	public function open() : Void { design.visible = true; }
	public function close() : Void { design.visible = false; }
	public function toggle() : Void { design.visible = !design.visible; }

	override public function update(dt : Float) : Void
	{
		tabView.update(dt);
	}

	function createSubView(tab : SettingsTab) : Null<SubView<Dynamic>>
	{
		return switch (tab)
		{
			case Audio: new SettingsContentSubView(bus, new SettingsAudioContent());
			case Display: new SettingsContentSubView(bus, new SettingsDisplayContent());
			case Controls: new SettingsContentSubView(bus, new SettingsControlsContent());
			case Gameplay: new SettingsContentSubView(bus, new SettingsGameplayContent());
		}
	}
}