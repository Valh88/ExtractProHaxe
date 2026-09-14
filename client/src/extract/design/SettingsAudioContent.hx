package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.utils.ui.Slider;

@:uiComp("settings-audio-content")
class SettingsAudioContent extends Flow implements Object
{
	static var SRC =
		<settings-audio-content class="settings-content">
			<flow id="masterWrap" class="settings-content-row" x="0" y="0"/>
			<flow id="musicWrap" class="settings-content-row" x="0" y="50"/>
			<flow id="sfxWrap" class="settings-content-row" x="0" y="100"/>
		</settings-audio-content>;

	public var master(default, null) : Slider;
	public var music(default, null) : Slider;
	public var sfx(default, null) : Slider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		master = new Slider(masterWrap);
		master.setLabel("MASTER");
		master.setNormalized(0.8);

		music = new Slider(musicWrap);
		music.setLabel("MUSIC");
		music.setNormalized(0.6);

		sfx = new Slider(sfxWrap);
		sfx.setLabel("SFX");
		sfx.setNormalized(0.4);
	}
}
