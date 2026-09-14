package extract.utils.ui;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

/**
	Generic reusable horizontal slider (domkit `ui-slider` component).
	Drags with a held left mouse button; a single click sets the value at once.
	Visuals are drawn with Graphics (track bg, fill, knob); the domkit markup
	provides the label/value texts and the track hit-area.
**/
@:uiComp("ui-slider")
class Slider extends Flow implements Object
{
	static var SRC =
		<ui-slider class="ui-slider">
			<text id="label" class="ui-slider-label" x="0" y="0"/>
			<flow id="trackWrap" class="ui-slider-track" x="310" y="13"/>
			<text id="valueText" class="ui-slider-value" x="452" y="9"/>
		</ui-slider>;

	public var onChange : Null<Float -> Void>;

	/** Track length in px — used for value mapping (matches `.ui-slider-track` width). */
	public static inline var TRACK_W : Int = 130;
	static inline var TRACK_H : Int = 14;
	static inline var KNOB_R : Int = 10;

	var normalized : Float = 1.0;
	var fillGfx : Graphics;
	var knobGfx : Graphics;

	var dragging : Bool = false;
	var win : hxd.Window;
	// bound once: Window.removeEventTarget matches by reference, and HL creates
	// a new closure on every method-field access — add/remove must share one
	final winMove : hxd.Event -> Void;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		getProperties(trackWrap).isAbsolute = true;
		getProperties(valueText).isAbsolute = true;
		valueText.text = "100%";
		valueText.x = 450;
		valueText.y = 9;

		win = hxd.Window.getInstance();
		winMove = onWinMove;

		var trackBg = new Graphics();
		trackBg.beginFill(0x1A1208);
		trackBg.drawRoundedRect(0, 0, TRACK_W, TRACK_H, 7);
		trackBg.endFill();
		trackBg.lineStyle(1, 0x45382A);
		trackBg.drawRoundedRect(0, 0, TRACK_W, TRACK_H, 7);
		trackBg.lineStyle(0);
		trackWrap.addChild(trackBg);
		trackWrap.getProperties(trackBg).isAbsolute = true;

		fillGfx = new Graphics();
		trackWrap.addChild(fillGfx);
		trackWrap.getProperties(fillGfx).isAbsolute = true;

		knobGfx = new Graphics();
		knobGfx.beginFill(0xE0D080);
		knobGfx.drawCircle(KNOB_R, KNOB_R, KNOB_R);
		knobGfx.endFill();
		addChild(knobGfx);
		getProperties(knobGfx).isAbsolute = true;

		trackWrap.enableInteractive = true;
		trackWrap.interactive.cursor = Button;
		// drag with the mouse button held: press sets the value at once, the
		// window-level move handler keeps tracking while the button is down
		trackWrap.interactive.onPush = function(e : hxd.Event) {
			dragging = true;
			applyFrom(e.relX);
			// guard against double-registration (e.g. rapid re-press)
			win.removeEventTarget(winMove);
			win.addEventTarget(winMove);
		};
		trackWrap.interactive.onRelease = endDrag;
		trackWrap.interactive.onReleaseOutside = endDrag;

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

		knobGfx.x = 310 + normalized * TRACK_W - KNOB_R;
		knobGfx.y = 11;
	}

	public function getNormalized() : Float { return normalized; }

	function endDrag(e : hxd.Event) : Void
	{
		dragging = false;
		win.removeEventTarget(winMove);
	}

	/** Window-space mouse moved while dragging. */
	function onWinMove(e : hxd.Event) : Void
	{
		if (!dragging) return;
		var gx = trackWrap.localToGlobal().x;
		applyFrom(e.relX - gx);
	}

	/** Apply a position relative to the track origin and fire onChange. */
	function applyFrom(trackX : Float) : Void
	{
		setNormalized(Math.max(0, Math.min(1, trackX / TRACK_W)));
		if (onChange != null) onChange(normalized);
	}
}