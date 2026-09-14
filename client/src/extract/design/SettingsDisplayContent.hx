package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.utils.ui.Toggle;
import extract.utils.ui.Slider;

@:uiComp("settings-display-content")
class SettingsDisplayContent extends Flow implements Object
{
	static var SRC =
		<settings-display-content class="settings-content">
			<flow id="resWrap" class="settings-content-row" x="0" y="0"/>
			<flow id="fullWrap" class="settings-content-row" x="0" y="50"/>
			<flow id="vsyncWrap" class="settings-content-row" x="0" y="100"/>
			<flow id="fpsWrap" class="settings-content-row" x="0" y="150"/>
			<flow id="brightWrap" class="settings-content-row" x="0" y="200"/>
		</settings-display-content>;

	public var resolution(default, null) : SettingsSelect;
	public var fullscreen(default, null) : Toggle;
	public var vsync(default, null) : Toggle;
	public var fpsLimit(default, null) : Slider;
	public var brightness(default, null) : Slider;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		resolution = new SettingsSelect(resWrap);
		resolution.setLabel("RESOLUTION");
		resolution.setOptions(["1920 × 1080", "1600 × 900", "1280 × 720"]);
		resolution.setSelectedIndex(0);

		fullscreen = new Toggle(fullWrap);
		fullscreen.setLabel("FULLSCREEN");
		fullscreen.setValue(true);

		vsync = new Toggle(vsyncWrap);
		vsync.setLabel("V-SYNC");
		vsync.setValue(false);

		fpsLimit = new Slider(fpsWrap);
		fpsLimit.setLabel("FPS LIMIT");
		fpsLimit.setNormalized(0.3);

		brightness = new Slider(brightWrap);
		brightness.setLabel("BRIGHTNESS");
		brightness.setNormalized(0.85);
	}
}
