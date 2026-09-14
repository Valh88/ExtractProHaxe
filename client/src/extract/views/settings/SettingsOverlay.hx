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
import extract.utils.animations.AnimationController;
import extract.utils.animations.Easing;
import extract.utils.animations.VarTween;
import shared.events.EventBus;
import extract.fsm.GameplayToggleRequest;

class SettingsOverlay extends SubView<SettingsDesign>
{
	var settings : SettingsDesign;
	var style : Style;
	var tabView : TabView<SettingsTab>;
	var fadeAnim : Null<SettingsOverlaySlideAnim>;
	var hudObj : Null<h2d.Object>;
	var ctrl : AnimationController = new AnimationController();

	public function new(bus : EventBus, style : Style, ?hudObj : h2d.Object, ?parent : Object)
	{
		settings = new SettingsDesign();
		super(bus, settings, parent);
		this.style = style;
		this.hudObj = hudObj;

		settings.onBack = function() bus.publish(new GameplayToggleRequest());
		settings.onSave = function() bus.publish(new GameplayToggleRequest());

		tabView = new TabView<SettingsTab>(settings.getContentWrap(), style, createSubView);

		settings.onTabClick = function(idx : Int)
		{
			settings.setTab(idx);
			tabView.switchToAnimated(Type.createEnumIndex(SettingsTab, idx));
		};

		tabView.switchTo(SettingsTab.Audio);

		design.visible = false;
	}

	public function open() : Void
	{
		design.visible = true;
		fadeAnim = new SettingsOverlaySlideAnim(null, this, design, 0.4, false);
		fadeAnim.start();
		if (hudObj != null)
			ctrl.add(new VarTween(hudObj, "alpha", 1, 0, 0.4, Easing.cubicOut));
	}

	public function close() : Void
	{
		fadeAnim = new SettingsOverlaySlideAnim(this, null, design, 0.4, true);
		fadeAnim.onComplete = function() { design.visible = false; };
		fadeAnim.start();
		if (hudObj != null)
			ctrl.add(new VarTween(hudObj, "alpha", 0, 1, 0.4, Easing.cubicIn));
	}

	override public function update(dt : Float) : Void
	{
		ctrl.update(dt);
		if (fadeAnim != null)
		{
			fadeAnim.update(dt);
			if (fadeAnim.isComplete) fadeAnim = null;
		}
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
