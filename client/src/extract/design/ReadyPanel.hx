package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;
import extract.design.PlayerChip;

@:uiComp("ready-panel")
class ReadyPanel extends Flow implements Object
{
	static var SRC =
		<ready-panel>
			<flow class="ready-inner" x="2" y="2">
				<flow id="titleWrap" class="ready-title-wrap" x="0" y="12">
					<text id="title" class="ready-title"/>
				</flow>
				<flow id="playerGroup" class="player-group" x="135" y="45"/>
			</flow>
		</ready-panel>;

	var panelBg : Graphics;
	var chipCount : Int = 0;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		panelBg = new Graphics();
		this.addChildAt(panelBg, 0);
		drawPanelBg();
		titleWrap.horizontalAlign = Middle;
		title.text = "READY";
		addChip(PlayerChip.READY);
		addChip(PlayerChip.WAITING);
		addChip(PlayerChip.NOT_READY);
	}

	function drawPanelBg()
	{
		panelBg.clear();
		panelBg.beginFill(0xC8956C);
		panelBg.drawRoundedRect(0, 0, 600, 190, 6);
		panelBg.endFill();
		panelBg.beginFill(0x1A1208);
		panelBg.drawRoundedRect(2, 2, 596, 186, 4);
		panelBg.endFill();
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

	public function show() : Void
	{
		this.visible = true;
	}

	public function hide() : Void
	{
		this.visible = false;
	}
}
