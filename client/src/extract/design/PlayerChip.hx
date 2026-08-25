package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("player-chip")
class PlayerChip extends Flow implements Object
{
	public static inline var READY = "ready";
	public static inline var WAITING = "waiting";
	public static inline var NOT_READY = "notready";

	static var SRC =
		<player-chip class="chip">
			<flow class="chip-bg" x="2" y="2">
				<flow class="chip-frame" x="10" y="8">
					<flow class="chip-icon" x="2" y="2"/>
				</flow>
			</flow>
			<text id="status" class="status" x="35" y="86"/>
		</player-chip>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
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
	}
}
