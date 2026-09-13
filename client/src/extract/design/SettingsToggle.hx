package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

@:uiComp("settings-toggle")
class SettingsToggle extends Flow implements Object
{
	static var SRC =
		<settings-toggle class="settings-toggle">
			<text id="label" class="settings-toggle-label" x="0" y="0"/>
			<flow id="pillWrap" class="settings-toggle-pill" x="476" y="7">
				<flow id="knobWrap" class="settings-toggle-knob" x="4" y="3"/>
			</flow>
		</settings-toggle>;

	public var onChange : Null<Bool -> Void>;

	var onColor : Int = 0xE0D080;
	var offColor : Int = 0x4A4036;
	var value : Bool = false;

	public function new(?parent)
	{
		super(parent);
		initComponent();

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
		knobWrap.x = v ? 24 : 4;
		knobWrap.dom.removeClass(value ? "settings-toggle-off" : "settings-toggle-on");
		knobWrap.dom.addClass(value ? "settings-toggle-on" : "settings-toggle-off");
		redrawKnob();
	}

	public function getValue() : Bool
	{
		return value;
	}

	function redrawKnob() : Void
	{
		knobWrap.removeChildren();
		var g = new Graphics();
		g.beginFill(value ? onColor : offColor);
		g.drawCircle(10, 10, 10);
		g.endFill();
		knobWrap.addChild(g);
	}
}
