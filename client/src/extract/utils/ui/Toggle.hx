package extract.utils.ui;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

/**
	Generic reusable toggle (domkit `ui-toggle` component): pill-shaped checkbox
	with a sliding knob. The pill is the hit area; visuals are Graphics-drawn,
	the markup provides the label text.
**/
@:uiComp("ui-toggle")
class Toggle extends Flow implements Object
{
	static var SRC =
		<ui-toggle class="ui-toggle">
			<text id="label" class="ui-toggle-label" x="0" y="0"/>
			<flow id="pillWrap" class="ui-toggle-pill" x="436" y="7"/>
		</ui-toggle>;

	public var onChange : Null<Bool -> Void>;

	var onColor : Int = 0xE0D080;
	var offColor : Int = 0x4A4036;
	var value : Bool = false;
	var pillBg : Graphics;
	var knobGfx : Graphics;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		getProperties(pillWrap).isAbsolute = true;

		pillBg = new Graphics();
		pillWrap.addChildAt(pillBg, 0);
		pillWrap.getProperties(pillBg).isAbsolute = true;

		knobGfx = new Graphics();
		addChild(knobGfx);
		getProperties(knobGfx).isAbsolute = true;

		pillWrap.enableInteractive = true;
		pillWrap.interactive.cursor = Button;
		pillWrap.interactive.onClick = function(_) {
			setValue(!value);
			if (onChange != null) onChange(value);
		};

		setValue(false);
	}

	public function setLabel(t : String) : Void { label.text = t; }

	public function setValue(v : Bool) : Void
	{
		value = v;

		pillBg.clear();
		pillBg.beginFill(value ? 0x6B6040 : 0x2E2620);
		pillBg.drawRoundedRect(0, 0, 44, 20, 10);
		pillBg.endFill();

		knobGfx.clear();
		knobGfx.beginFill(value ? onColor : offColor);
		knobGfx.drawCircle(10, 10, 10);
		knobGfx.endFill();
		knobGfx.x = 436 + (value ? 24 : 4);
		knobGfx.y = 7 + 1;
	}

	public function getValue() : Bool
	{
		return value;
	}
}