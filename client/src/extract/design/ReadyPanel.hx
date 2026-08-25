package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Right-hand "READY" panel holding the three player chips. */
@:uiComp("ready-panel")
class ReadyPanel extends Flow implements Object
{
	static var SRC =
		<ready-panel>
			<text id="readyTitle" class="ready-title" x="296" y="12"/>
			<player-chip class="player-chip-ready" label={"READY"} x="135" y="24"/>
			<player-chip class="player-chip-waiting" label={"WAITING"} x="217" y="24"/>
			<player-chip class="player-chip-notready" label={"NOT READY"} x="299" y="24"/>
		</ready-panel>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		readyTitle.text = "READY";
	}
}
