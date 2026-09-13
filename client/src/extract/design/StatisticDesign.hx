package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("statistic-design")
class StatisticDesign extends Flow implements Object
{
	static var SRC =
		<statistic-design class="statistic-root">
			<text id="fpsCaption" class="stat-caption" x="0" y="0"/>
			<text id="fpsValue" class="stat-value" x="50" y="0"/>
			<text id="pingCaption" class="stat-caption" x="0" y="22"/>
			<text id="pingValue" class="stat-value" x="50" y="22"/>
		</statistic-design>;

	public var fpsValueText(get, never) : String;
	public var pingValueText(get, never) : String;

	var fpsCaption : h2d.Text;
	var fpsValue : h2d.Text;
	var pingCaption : h2d.Text;
	var pingValue : h2d.Text;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		fpsCaption.text = "Fps:";
		fpsValue.text = "0";
		pingCaption.text = "Ping:";
		pingValue.text = "0";
	}

	function get_fpsValueText() : String
	{
		return fpsValue.text;
	}

	function get_pingValueText() : String
	{
		return pingValue.text;
	}

	/** Update displayed FPS value (call from system). */
	public function setFps(v : Int) : Void
	{
		fpsValue.text = Std.string(v);
	}

	/** Update displayed ping value in ms (call from system). */
	public function setPing(v : Int) : Void
	{
		pingValue.text = Std.string(v);
	}
}
