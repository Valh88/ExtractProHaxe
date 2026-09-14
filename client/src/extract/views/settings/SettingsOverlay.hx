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
import extract.fsm.GameplayToggleRequest;

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

		settings.onBack = function() bus.publish(new GameplayToggleRequest());
		settings.onSave = function() bus.publish(new GameplayToggleRequest());

		tabView = new TabView<SettingsTab>(settings.getContentWrap(), style, createSubView);

		settings.onTabClick = function(idx : Int)
		{
			settings.setTab(idx);
			tabView.switchToAnimated(Type.createEnumIndex(SettingsTab, idx));
		};

		tabView.switchTo(SettingsTab.Audio);
	}

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