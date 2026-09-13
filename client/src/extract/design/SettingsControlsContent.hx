package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-controls-content")
class SettingsControlsContent extends Flow implements Object
{
	static var SRC =
		<settings-controls-content class="settings-content">
			<flow id="sensWrap" x="0" y="0"/>
			<flow id="invertWrap" x="0" y="50"/>
			<text id="sectionKeybindings" class="settings-section" x="0" y="110"/>
			<flow id="keyMoveWrap" x="0" y="150"/>
			<flow id="keyFireWrap" x="0" y="190"/>
			<flow id="keyCrouchWrap" x="0" y="230"/>
			<flow id="keySkillsWrap" x="0" y="270"/>
			<flow id="resetBtn" class="settings-reset-btn" x="0" y="330">
				<text id="resetTxt" class="settings-reset-text" x="0" y="0"/>
			</flow>
		</settings-controls-content>;

	public var sensitivity(default, null) : SettingsSlider;
	public var invertY(default, null) : SettingsToggle;
	public var keyMove(default, null) : SettingsKeybind;
	public var keyFire(default, null) : SettingsKeybind;
	public var keyCrouch(default, null) : SettingsKeybind;
	public var keySkills(default, null) : SettingsKeybind;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		sensitivity = new SettingsSlider(sensWrap);
		sensitivity.setLabel("MOUSE SENSITIVITY");
		sensitivity.setNormalized(0.7);

		invertY = new SettingsToggle(invertWrap);
		invertY.setLabel("INVERT Y");
		invertY.setValue(false);

		sectionKeybindings.text = "KEYBINDINGS";

		keyMove = new SettingsKeybind(keyMoveWrap);
		keyMove.setLabel("MOVE");
		keyMove.setKey("W A S D");

		keyFire = new SettingsKeybind(keyFireWrap);
		keyFire.setLabel("FIRE");
		keyFire.setKey("LMB");

		keyCrouch = new SettingsKeybind(keyCrouchWrap);
		keyCrouch.setLabel("CROUCH");
		keyCrouch.setKey("C");

		keySkills = new SettingsKeybind(keySkillsWrap);
		keySkills.setLabel("SKILLS");
		keySkills.setKey("1 · 2 · 3 · 4 · 5 · 6");

		resetTxt.text = "RESET TO DEFAULT";

		resetBtn.enableInteractive = true;
		resetBtn.interactive.cursor = Button;
	}
}
