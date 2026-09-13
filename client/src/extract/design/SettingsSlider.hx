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
			<flow id="trackWrap" class="settings-slider-track" x="310" y="13">
				<flow id="fill" class="settings-slider-fill" x="0" y="0"/>
			</flow>
			<flow id="knobWrap" class="settings-slider-knob" x="310" y="6"/>
			<text id="valueText" class="settings-slider-value" x="460" y="0"/>
		</settings-slider>;

	/** Fired when the user drags the knob. 0..1 normalized. */
	public var onChange : Null<Float -> Void>;

	var knobGfx : Graphics;
	var trackWrap : Flow;
	var fill : Flow;
	var knobWrap : Flow;

	/** Track inner width (pixels between track edges). */
	static inline var TRACK_W : Int = 190;
	/** Knob center offset. */
	static inline var KNOB_R : Int = 14;

	var normalized : Float = 1.0;
	var dragging : Bool = false;

	public function new(?parent, ?labelText : String)
	{
		super(parent);
		initComponent();

		label.text = labelText != null ? labelText : "";
		valueText.text = "100%";

		knobGfx = new Graphics();
		knobWrap.addChild(knobGfx);
		drawKnob(knobGfx, 0xE0D080);

		trackWrap.enableInteractive = true;
		trackWrap.interactive.cursor = Button;
		trackWrap.interactive.onClick = onTrackClick;
		trackWrap.interactive.onPush = function(_) { dragging = true; };
		trackWrap.interactive.onRelease = function(_) { dragging = false; };
		trackWrap.interactive.onMove = function(e) { if (dragging) onTrackMove(e); };

		knobWrap.enableInteractive = true;
		knobWrap.interactive.cursor = Button;
		knobWrap.interactive.onPush = function(_) { dragging = true; };
		knobWrap.interactive.onRelease = function(_) { dragging = false; };
		knobWrap.interactive.onMove = function(e) { if (dragging) onTrackMove(e); };

		setNormalized(1.0);
	}

	public function setNormalized(v : Float) : Void
	{
		normalized = Math.max(0, Math.min(1, v));
		var pct = Math.round(normalized * 100);
		valueText.text = pct + "%";

		var fillW = Math.round(normalized * TRACK_W);
		fill.width = fillW > 0 ? fillW : 1;

		knobWrap.x = 310 + Math.round(normalized * TRACK_W) - KNOB_R;
	}

	public function getNormalized() : Float
	{
		return normalized;
	}

	function onTrackClick(_) : Void
	{
		var local = trackWrap.interactive.mouseX;
		setNormalized(local / TRACK_W);
		if (onChange != null) onChange(normalized);
	}

	function onTrackMove(_) : Void
	{
		var local = trackWrap.interactive.mouseX;
		setNormalized(Math.max(0, Math.min(1, local / TRACK_W)));
		if (onChange != null) onChange(normalized);
	}

	static function drawKnob(g : Graphics, color : Int) : Void
	{
		g.clear();
		g.beginFill(color);
		g.drawCircle(KNOB_R, KNOB_R, KNOB_R);
		g.endFill();
	}
}
