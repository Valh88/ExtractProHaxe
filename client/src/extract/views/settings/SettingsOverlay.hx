package extract.views.settings;

import h2d.Flow;
import h2d.Object;
import extract.design.SettingsDesign;
import extract.utils.SubView;
import extract.utils.SubViewSwitcher;
import shared.events.EventBus;

class SettingsOverlay extends SubView<SettingsDesign>
{
	var settings : SettingsDesign;
	var tabSwitcher : SubViewSwitcher<SettingsTab>;

	public var activeTab(default, null) : SettingsTab = Audio;

	public function new(bus : EventBus, ?parent : Object)
	{
		settings = new SettingsDesign();
		super(bus, settings, parent);

		settings.onBack = close;
		settings.onSave = close;

		tabSwitcher = new SubViewSwitcher<SettingsTab>(
			createTabView,
			null,
			function(tab : SettingsTab)
			{
				activeTab = tab;
				settings.setTab(Type.enumIndex(tab));
			}
		);

		setTab(Audio);
	}

	public function open() : Void
	{
		design.visible = true;
	}

	public function close() : Void
	{
		design.visible = false;
	}

	public function setTab(tab : SettingsTab) : Void
	{
		tabSwitcher.switchTo(tab);
	}

	public function toggle() : Void
	{
		design.visible = !design.visible;
	}

	function createTabView(tab : SettingsTab) : Null<SubView<Dynamic>>
	{
		var content : Flow = switch (tab)
		{
			case Audio: settings.getContent(0);
			case Display: settings.getContent(1);
			case Controls: settings.getContent(2);
			case Gameplay: settings.getContent(3);
		}

		var sub : SubView<Dynamic> = switch (tab)
		{
			case Audio: new SettingsAudioSubView(bus);
			case Display: new SettingsDisplaySubView(bus);
			case Controls: new SettingsControlsSubView(bus);
			case Gameplay: new SettingsGameplaySubView(bus);
		}

		if (content != null) content.addChild(sub.design);
		return sub;
	}
}
