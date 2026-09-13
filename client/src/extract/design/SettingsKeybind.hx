package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-keybind")
class SettingsKeybind extends Flow implements Object
{
	static var SRC =
		<settings-keybind class="settings-keybind">
			<text id="label" class="settings-keybind-label" x="0" y="0"/>
			<flow id="boxWrap" class="settings-keybind-box" x="310" y="4">
				<text id="keyText" class="settings-keybind-text" x="0" y="0"/>
			</flow>
		</settings-keybind>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		getProperties(boxWrap).isAbsolute = true;
	}

	public function setLabel(t : String) : Void { label.text = t; }

	public function setKey(key : String) : Void
	{
		keyText.text = key;
	}

	public function getKey() : String
	{
		return keyText.text;
	}
}
