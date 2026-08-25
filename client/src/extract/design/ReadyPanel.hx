package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/**
	Bottom-left "READY" panel with three player chips, built from the
	Lunacy `CheckReadingDesign` frame. Status colors:
	READY #1ACC19, WAITING #B3B319, NOT READY #B33333.
**/
@:uiComp("ready-panel")
class ReadyPanel extends Flow implements Object
{
	static var SRC =
		<ready-panel>
			<flow class="ready-inner" x="2" y="2">
				<text id="title" class="ready-title" x="296" y="12"/>
				<flow class="player-group" x="135" y="45">
					<flow class="chip chip-ready" x="0" y="0">
						<flow class="chip-frame" x="12" y="10"/>
						<text id="s1" class="status-ready" x="40" y="86"/>
					</flow>
					<flow class="chip chip-waiting" x="82" y="0">
						<flow class="chip-frame" x="12" y="10"/>
						<text id="s2" class="status-waiting" x="31" y="86"/>
					</flow>
					<flow class="chip chip-notready" x="164" y="0">
						<flow class="chip-frame" x="12" y="10"/>
						<text id="s3" class="status-notready" x="22" y="86"/>
					</flow>
				</flow>
			</flow>
		</ready-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		title.text = "READY";
		s1.text = "READY";
		s2.text = "WAITING";
		s3.text = "NOT READY";
	}
}
