package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-display-content")
class SettingsDisplayContent extends Flow implements Object
{
	static var SRC =
		<settings-display-content class="settings-content">
			<flow id="resWrap" x="0" y="0"/>
			<flow id="fullWrap" x="0" y="50"/>
			<flow id="vsyncWrap" x="0" y="100"/>
			<flow id="fpsWrap" x="0" y="150"/>
			<flow id="brightWrap" x="0" y="200"/>
		</settings-display-content>;

	public var resolution(default, null) : SettingsSelect;
	public var fullscreen(default, null) : SettingsToggle;
	public var vsync(default, null) : SettingsToggle;
	public var fpsLimit(default, null) : SettingsSlider;
	public var brightness(default, null) : SettingsSlider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		resolution = new SettingsSelect(resWrap);
		resolution.setLabel("RESOLUTION");
		resolution.setOptions(["1920 × 1080", "1600 × 900", "1280 × 720"]);
		resolution.setSelectedIndex(0);

		fullscreen = new SettingsToggle(fullWrap);
		fullscreen.setLabel("FULLSCREEN");
		fullscreen.setValue(true);

		vsync = new SettingsToggle(vsyncWrap);
		vsync.setLabel("V-SYNC");
		vsync.setValue(false);

		fpsLimit = new SettingsSlider(fpsWrap);
		fpsLimit.setLabel("FPS LIMIT");
		fpsLimit.setNormalized(0.3);

		brightness = new SettingsSlider(brightWrap);
		brightness.setLabel("BRIGHTNESS");
		brightness.setNormalized(0.85);
	}
}
