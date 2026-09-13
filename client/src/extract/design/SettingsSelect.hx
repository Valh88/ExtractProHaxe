package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-select")
class SettingsSelect extends Flow implements Object
{
	static var SRC =
		<settings-select class="settings-select">
			<text id="label" class="settings-select-label" x="0" y="0"/>
			<flow id="boxWrap" class="settings-select-box" x="310" y="6">
				<text id="valueText" class="settings-select-text" x="0" y="0"/>
			</flow>
		</settings-select>;

	/** Fired on selection change. Index of the selected option. */
	public var onChange : Null<Int -> Void>;

	var options : Array<String>;
	var selectedIndex : Int = 0;

	public function new(?parent, ?labelText : String, ?opts : Array<String>)
	{
		super(parent);
		initComponent();

		label.text = labelText != null ? labelText : "";
		options = opts != null ? opts : [];
		if (options.length > 0)
			setSelectedIndex(0);

		boxWrap.enableInteractive = true;
		boxWrap.interactive.cursor = Button;
		boxWrap.interactive.onClick = function(_) cycleOption();
	}

	public function setOptions(opts : Array<String>) : Void
	{
		options = opts;
		selectedIndex = 0;
		if (options.length > 0)
			updateText();
	}

	public function setSelectedIndex(i : Int) : Void
	{
		if (options.length == 0) return;
		selectedIndex = i % options.length;
		if (selectedIndex < 0) selectedIndex += options.length;
		updateText();
	}

	public function getSelectedIndex() : Int
	{
		return selectedIndex;
	}

	public function getSelectedOption() : String
	{
		if (options.length == 0) return "";
		return options[selectedIndex];
	}

	function cycleOption() : Void
	{
		if (options.length == 0) return;
		selectedIndex = (selectedIndex + 1) % options.length;
		updateText();
		if (onChange != null) onChange(selectedIndex);
	}

	function updateText() : Void
	{
		valueText.text = options.length > 0 ? options[selectedIndex] : "";
	}
}
