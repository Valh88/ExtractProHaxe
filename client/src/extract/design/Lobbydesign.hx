package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.design.ReadyPanel;

class Lobbydesign extends Flow implements Object
{
	static var SRC =
		<lobbydesign class="lobby-root">
			<top-panel id="topPanel" class="top-panel" x="0" y="0"/>
			<ready-panel id="readyPanel" class="ready-panel" x="660" y="90"/>
			<bottom-panel class="bottom-panel" x="0" y="1010"/>
			<text id="hunt" class="hunt-title" x="1573" y="114"/>
			<text id="sub" class="subtitle" x="1650" y="215"/>
			<flow id="subViewDesign" class="sub-view"/>
		</lobbydesign>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		hunt.text = "HUNT";
		sub.text = "SHOWDOWN";
		readyPanel.hide();
	}

	public function getSubViewDesign() : h2d.Flow return subViewDesign;

	public function getReadyPanel() : ReadyPanel return readyPanel;

	public function getTopPanel() : TopPanel return topPanel;
}
