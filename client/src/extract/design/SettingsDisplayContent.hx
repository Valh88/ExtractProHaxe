package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-display-content")
class SettingsDisplayContent extends Flow implements Object
{
	static var SRC =
		<settings-display-content class="settings-content">
			<settings-select id="resSelect" x="0" y="0"/>
			<settings-toggle id="fullscreenToggle" x="0" y="50"/>
			<settings-toggle id="vsyncToggle" x="0" y="100"/>
			<settings-slider id="fpsLimitSlider" x="0" y="150"/>
			<settings-slider id="brightnessSlider" x="0" y="200"/>
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

		resolution = resSelect;
		resolution.label.text = "RESOLUTION";
		resolution.setOptions(["1920 × 1080", "1600 × 900", "1280 × 720"]);
		resolution.setSelectedIndex(0);

		fullscreen = fullscreenToggle;
		fullscreen.label.text = "FULLSCREEN";
		fullscreen.setValue(true);

		vsync = vsyncToggle;
		vsync.label.text = "V-SYNC";
		vsync.setValue(false);

		fpsLimit = fpsLimitSlider;
		fpsLimit.label.text = "FPS LIMIT";
		fpsLimit.setNormalized(0.3);

		brightness = brightnessSlider;
		brightness.label.text = "BRIGHTNESS";
		brightness.setNormalized(0.85);
	}
}
