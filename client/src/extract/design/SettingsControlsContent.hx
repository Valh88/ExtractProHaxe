package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-controls-content")
class SettingsControlsContent extends Flow implements Object
{
	static var SRC =
		<settings-controls-content class="settings-content">
			<settings-slider id="sensitivitySlider" x="0" y="0"/>
			<settings-toggle id="invertYToggle" x="0" y="50"/>
			<text id="sectionKeybindings" class="settings-section" x="0" y="110"/>
			<settings-keybind id="keyMove" x="0" y="150"/>
			<settings-keybind id="keyFire" x="0" y="190"/>
			<settings-keybind id="keyCrouch" x="0" y="230"/>
			<settings-keybind id="keySkills" x="0" y="270"/>
			<flow id="resetBtn" class="settings-reset-btn" x="0" y="330">
				<text id="resetTxt" class="settings-reset-text" x="0" y="0"/>
			</flow>
		</settings-controls-content>;

	public var sensitivity(default, null) : SettingsSlider;
	public var invertY(default, null) : SettingsToggle;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		sensitivity = sensitivitySlider;
		sensitivity.label.text = "MOUSE SENSITIVITY";
		sensitivity.setNormalized(0.7);

		invertY = invertYToggle;
		invertY.label.text = "INVERT Y";
		invertY.setValue(false);

		sectionKeybindings.text = "KEYBINDINGS";

		keyMove.label.text = "MOVE";
		keyMove.setKey("W A S D");

		keyFire.label.text = "FIRE";
		keyFire.setKey("LMB");

		keyCrouch.label.text = "CROUCH";
		keyCrouch.setKey("C");

		keySkills.label.text = "SKILLS";
		keySkills.setKey("1 · 2 · 3 · 4 · 5 · 6");

		resetTxt.text = "RESET TO DEFAULT";

		resetBtn.enableInteractive = true;
		resetBtn.interactive.cursor = Button;
	}
}
