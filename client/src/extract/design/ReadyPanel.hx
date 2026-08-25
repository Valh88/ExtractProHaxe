package extract.design;

import h2d.Flow;
import h2d.domkit.Object;
import extract.design.PlayerChip;

@:uiComp("ready-panel")
class ReadyPanel extends Flow implements Object
{
	static var SRC =
		<ready-panel>
			<flow class="ready-inner" x="2" y="2">
				<text id="title" class="ready-title" x="296" y="12"/>
				<flow id="playerGroup" class="player-group" x="135" y="45"/>
			</flow>
		</ready-panel>;

	var chipCount : Int = 0;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		title.text = "READY";
		addChip(PlayerChip.READY);
		addChip(PlayerChip.WAITING);
		addChip(PlayerChip.NOT_READY);
	}

	public function addChip(status : String) : PlayerChip
	{
		var chip = new PlayerChip(playerGroup);
		chip.x = chipCount * 82;
		chipCount++;
		chip.setStatus(status);
		return chip;
	}

	public function clearChips()
	{
		playerGroup.removeChildren();
		chipCount = 0;
	}
}
