package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/**
	Root of the lobby 2D HUD, built from the current Lunacy design:
	a top bar, a bottom bar and the HUNT / SHOWDOWN title.

	NOTE: Oswald / Inter fonts are not in the repo yet, so every text uses
	DefaultFont (sizes from the design can't be reproduced without .bfnt files).
	Once added, set `font: font/oswald-bold.bfnt 22;` etc. on the text classes.
**/
class Lobbydesign extends Flow implements Object
{
	static var SRC =
		<lobbydesign class="lobby-root">
			<top-panel class="top-panel" x="0" y="0"/>
			<bottom-panel class="bottom-panel" x="0" y="1010"/>
			<text id="hunt" class="hunt-title" x="1573" y="114"/>
			<text id="sub" class="subtitle" x="1650" y="215"/>
		</lobbydesign>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		hunt.text = "HUNT";
		sub.text = "SHOWDOWN";
	}
}
