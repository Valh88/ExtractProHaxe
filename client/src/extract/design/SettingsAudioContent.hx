package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-audio-content")
class SettingsAudioContent extends Flow implements Object
{
	static var SRC =
		<settings-audio-content class="settings-content">
			<settings-slider id="masterSlider" x="0" y="0"/>
			<settings-slider id="musicSlider" x="0" y="50"/>
			<settings-slider id="sfxSlider" x="0" y="100"/>
		</settings-audio-content>;

	public var master(default, null) : SettingsSlider;
	public var music(default, null) : SettingsSlider;
	public var sfx(default, null) : SettingsSlider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		master = masterSlider;
		master.label.text = "MASTER";
		master.setNormalized(0.8);

		music = musicSlider;
		music.label.text = "MUSIC";
		music.setNormalized(0.6);

		sfx = sfxSlider;
		sfx.label.text = "SFX";
		sfx.setNormalized(0.4);
	}
}
