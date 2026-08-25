package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** A single player status chip (READY / WAITING / NOT READY). */
@:uiComp("player-chip")
class PlayerChip extends Flow implements Object
{
	@:p public var label : String = "";

	static var SRC =
		<player-chip>
			<flow class="chip-icon"/>
			<text id="status" class="player-status" x="6" y="70"/>
		</player-chip>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		status.text = label;
	}
}
