package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.design.ReadyPanel;

class Lobbydesign extends Flow implements Object
{
	static var SRC =
		<lobbydesign class="lobby-root">
			<top-panel class="top-panel" x="0" y="0"/>
			<flow id="subContainer" class="play-view" x="0" y="0"/>
			<ready-panel class="ready-panel" x="40" y="620"/>
			<bottom-panel class="bottom-panel" x="0" y="1010"/>
			<text id="hunt" class="hunt-title" x="1573" y="114"/>
			<text id="sub" class="subtitle" x="1650" y="215"/>
		</lobbydesign>;

	public var subViewContainer(get, never) : Flow;
	function get_subViewContainer() return subContainer;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		hunt.text = "HUNT";
		sub.text = "SHOWDOWN";
	}
}
