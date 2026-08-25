package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/**
	Root of the lobby 2D HUD. Built entirely from domkit components
	(ModePanel / ReadyPanel) so every node has a valid `dom` and the
	CSS in ui/lobby.css applies through h2d.domkit.Style.

	NOTE: Oswald fonts are not in the repo yet, so text uses DefaultFont.
	Once Oswald .bfnt files exist, add `font: font/oswald-bold.bfnt 18;`
	(etc.) rules to the CSS classes below.
**/
class Lobbydesign extends Flow implements Object
{
	static var SRC =
		<lobbydesign class="lobby-root">
			<mode-panel class="mode-panel" x="40" y="40"/>
			<ready-panel class="ready-panel" x="380" y="200"/>
		</lobbydesign>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
	}
}
