package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.utils.ui.Toggle;
import extract.utils.ui.Slider;

@:uiComp("settings-gameplay-content")
class SettingsGameplayContent extends Flow implements Object
{
	static var SRC =
		<settings-gameplay-content class="settings-content">
			<flow id="langWrap" class="settings-content-row" x="0" y="0"/>
			<flow id="fpsWrap" class="settings-content-row" x="0" y="50"/>
			<flow id="namesWrap" class="settings-content-row" x="0" y="100"/>
			<flow id="hudWrap" class="settings-content-row" x="0" y="150"/>
			<text id="hint" class="settings-hint settings-content-row" x="0" y="220"/>
		</settings-gameplay-content>;

	public var language(default, null) : SettingsSelect;
	public var showFps(default, null) : Toggle;
	public var showNames(default, null) : Toggle;
	public var hudScale(default, null) : Slider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		language = new SettingsSelect(langWrap);
		language.setLabel("LANGUAGE");
		language.setOptions(["ENGLISH", "RUSSIAN", "DEUTSCH", "FRANCAIS"]);
		language.setSelectedIndex(0);

		showFps = new Toggle(fpsWrap);
		showFps.setLabel("SHOW FPS");
		showFps.setValue(true);

		showNames = new Toggle(namesWrap);
		showNames.setLabel("SHOW NAMES");
		showNames.setValue(false);

		hudScale = new Slider(hudWrap);
		hudScale.setLabel("HUD SCALE");
		hudScale.setNormalized(1.0);

		hint.text = "Prototype: more options will be added here";
	}
}
