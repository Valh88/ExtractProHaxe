package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-gameplay-content")
class SettingsGameplayContent extends Flow implements Object
{
	static var SRC =
		<settings-gameplay-content class="settings-content">
			<settings-select id="langSelect" x="0" y="0"/>
			<settings-toggle id="showFpsToggle" x="0" y="50"/>
			<settings-toggle id="showNamesToggle" x="0" y="100"/>
			<settings-slider id="hudScaleSlider" x="0" y="150"/>
			<text id="hint" class="settings-hint" x="0" y="220"/>
		</settings-gameplay-content>;

	public var language(default, null) : SettingsSelect;
	public var showFps(default, null) : SettingsToggle;
	public var showNames(default, null) : SettingsToggle;
	public var hudScale(default, null) : SettingsSlider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		language = langSelect;
		language.label.text = "LANGUAGE";
		language.setOptions(["ENGLISH", "RUSSIAN", "DEUTSCH", "FRANCAIS"]);
		language.setSelectedIndex(0);

		showFps = showFpsToggle;
		showFps.label.text = "SHOW FPS";
		showFps.setValue(true);

		showNames = showNamesToggle;
		showNames.label.text = "SHOW NAMES";
		showNames.setValue(false);

		hudScale = hudScaleSlider;
		hudScale.label.text = "HUD SCALE";
		hudScale.setNormalized(1.0);

		hint.text = "Prototype: more options will be added here";
	}
}
