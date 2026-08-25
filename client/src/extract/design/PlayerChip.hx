package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.domkit.Object;

@:uiComp("player-chip")
class PlayerChip extends Flow implements Object
{
	public static inline var READY = "ready";
	public static inline var WAITING = "waiting";
	public static inline var NOT_READY = "notready";

	static var SRC =
		<player-chip class="chip">
			<flow id="statusWrap" class="status-wrap" x="0" y="86">
				<text id="status" class="status"/>
			</flow>
		</player-chip>;

	var bg : Graphics;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		statusWrap.horizontalAlign = Middle;
		bg = new Graphics();
		this.addChildAt(bg, 0);
		setStatus(READY);
	}

	public function setStatus(s : String)
	{
		for (c in [READY, WAITING, NOT_READY])
			this.dom.removeClass("chip-" + c);
		this.dom.addClass("chip-" + s);
		status.text = switch (s)
		{
			case READY: "READY";
			case WAITING: "WAITING";
			default: "NOT READY";
		};
		drawBg(s);
	}

	function drawBg(state : String)
	{
		var border = switch (state)
		{
			case READY: 0xC8956C;
			case WAITING: 0x3A2A18;
			default: 0x3A2A18;
		};
		bg.clear();
		bg.beginFill(border);
		bg.drawRoundedRect(0, 0, 72, 104, 6);
		bg.endFill();
		bg.beginFill(0x1A1208);
		bg.drawRoundedRect(2, 2, 68, 100, 4);
		bg.endFill();
		bg.beginFill(border);
		bg.drawRoundedRect(12, 10, 48, 48, 4);
		bg.endFill();
		bg.beginFill(0x2A1A10);
		bg.drawRoundedRect(14, 12, 44, 44, 2);
		bg.endFill();
	}
}
