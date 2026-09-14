package extract.views.settings;

import h2d.Object;
import h2d.domkit.Style;
import extract.design.SettingsDesign;
import extract.design.SettingsAudioContent;
import extract.design.SettingsDisplayContent;
import extract.design.SettingsControlsContent;
import extract.design.SettingsGameplayContent;
import extract.utils.SubView;
import extract.utils.SubViewSwitcher;
import shared.events.EventBus;

class SettingsOverlay extends SubView<SettingsDesign>
{
	var settings : SettingsDesign;
	var style : Style;
	var subSwitcher : SubViewSwitcher<SettingsTab>;

	public function new(bus : EventBus, style : Style, ?parent : Object)
	{
		settings = new SettingsDesign();
		super(bus, settings, parent);
		this.style = style;

		// clip sub-view animations (slide in/out) to the content box
		settings.getContentWrap().overflow = h2d.Flow.FlowOverflow.Hidden;

		settings.onBack = close;
		settings.onSave = close;

		subSwitcher = new SubViewSwitcher<SettingsTab>(createSubView, attachSubView,
			function(tab : SettingsTab) settings.setTab(Type.enumIndex(tab)));

		settings.onTabClick = function(idx : Int)
			subSwitcher.switchToAnimated(Type.createEnumIndex(SettingsTab, idx));

		subSwitcher.switchTo(SettingsTab.Audio);
	}

	public function open() : Void { design.visible = true; }
	public function close() : Void { design.visible = false; }
	public function toggle() : Void { design.visible = !design.visible; }

	override public function update(dt : Float) : Void
	{
		subSwitcher.update(dt);
	}

	function attachSubView(sub : SubView<Dynamic>) : Void
	{
		var cw = settings.getContentWrap();
		cw.addChild(sub.design);
		cw.getProperties(sub.design).isAbsolute = true;
		style.addObject(sub.design);
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
