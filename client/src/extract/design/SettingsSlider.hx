package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

@:uiComp("settings-slider")
class SettingsSlider extends Flow implements Object
{
	static var SRC =
		<settings-slider class="settings-slider">
			<text id="label" class="settings-slider-label" x="0" y="0"/>
			<flow id="trackWrap" class="settings-slider-track" x="310" y="13"/>
			<flow id="knobWrap" class="settings-slider-knob" x="310" y="6"/>
			<text id="valueText" class="settings-slider-value" x="460" y="0"/>
		</settings-slider>;

	public var onChange : Null<Float -> Void>;

	static inline var TRACK_W : Int = 190;
	static inline var TRACK_H : Int = 14;
	static inline var KNOB_R : Int = 14;

	var normalized : Float = 1.0;
	var fillGfx : Graphics;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		valueText.text = "100%";

		var trackBg = new Graphics();
		trackBg.beginFill(0x1A1208);
		trackBg.drawRoundedRect(0, 0, TRACK_W, TRACK_H, 7);
		trackBg.endFill();
		trackBg.lineStyle(1, 0x45382A);
		trackBg.drawRoundedRect(0, 0, TRACK_W, TRACK_H, 7);
		trackBg.lineStyle(0);
		trackWrap.addChild(trackBg);

		fillGfx = new Graphics();
		trackWrap.addChild(fillGfx);

		var knobGfx = new Graphics();
		knobGfx.beginFill(0xE0D080);
		knobGfx.drawCircle(KNOB_R, KNOB_R, KNOB_R);
		knobGfx.endFill();
		knobWrap.addChild(knobGfx);

		trackWrap.enableInteractive = true;
		trackWrap.interactive.cursor = Button;
		trackWrap.interactive.onClick = function(e) {
			setNormalized(Math.max(0, Math.min(1, e.relX / TRACK_W)));
			if (onChange != null) onChange(normalized);
		};

		setNormalized(1.0);
	}

	public function setLabel(t : String) : Void { label.text = t; }

	public function setNormalized(v : Float) : Void
	{
		normalized = Math.max(0, Math.min(1, v));
		valueText.text = Math.round(normalized * 100) + "%";

		var fillW = Std.int(Math.max(1, normalized * TRACK_W));
		fillGfx.clear();
		fillGfx.beginFill(0xC4A44A);
		fillGfx.drawRoundedRect(0, 0, fillW, TRACK_H, 7);
		fillGfx.endFill();

		knobWrap.x = 310 + Std.int(normalized * TRACK_W) - KNOB_R;
	}

	public function getNormalized() : Float { return normalized; }
}
