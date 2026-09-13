package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-audio-content")
class SettingsAudioContent extends Flow implements Object
{
	static var SRC =
		<settings-audio-content class="settings-content">
			<flow id="masterWrap" x="0" y="0"/>
			<flow id="musicWrap" x="0" y="50"/>
			<flow id="sfxWrap" x="0" y="100"/>
		</settings-audio-content>;

	public var master(default, null) : SettingsSlider;
	public var music(default, null) : SettingsSlider;
	public var sfx(default, null) : SettingsSlider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		master = new SettingsSlider(masterWrap);
		master.setLabel("MASTER");
		master.setNormalized(0.8);

		music = new SettingsSlider(musicWrap);
		music.setLabel("MUSIC");
		music.setNormalized(0.6);

		sfx = new SettingsSlider(sfxWrap);
		sfx.setLabel("SFX");
		sfx.setNormalized(0.4);
	}
}
