package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-gameplay-content")
class SettingsGameplayContent extends Flow implements Object
{
	static var SRC =
		<settings-gameplay-content class="settings-content">
			<flow id="langWrap" x="0" y="0"/>
			<flow id="fpsWrap" x="0" y="50"/>
			<flow id="namesWrap" x="0" y="100"/>
			<flow id="hudWrap" x="0" y="150"/>
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

		language = new SettingsSelect(langWrap);
		language.setLabel("LANGUAGE");
		language.setOptions(["ENGLISH", "RUSSIAN", "DEUTSCH", "FRANCAIS"]);
		language.setSelectedIndex(0);

		showFps = new SettingsToggle(fpsWrap);
		showFps.setLabel("SHOW FPS");
		showFps.setValue(true);

		showNames = new SettingsToggle(namesWrap);
		showNames.setLabel("SHOW NAMES");
		showNames.setValue(false);

		hudScale = new SettingsSlider(hudWrap);
		hudScale.setLabel("HUD SCALE");
		hudScale.setNormalized(1.0);

		hint.text = "Prototype: more options will be added here";
	}
}
