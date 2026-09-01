package extract.views.lobby;

import h2d.Object;
import extract.design.PlayDesign;
import extract.views.SubView;

class PlaySubView extends SubView
{
	var playDesign : PlayDesign;

	/** Selected team size (client-side for now). */
	public var mode(default, null) : LobbyMode = LobbyMode.Solo;

	public function new(?parent : Object)
	{
		super(parent);
		playDesign = new PlayDesign();
		design = playDesign;

		var mp = playDesign.getModePanel();
		mp.setActiveMode(mode == LobbyMode.Solo); // default state -> design
		mp.onModeSelect = onModeSelect;
		mp.onSearch = onSearchClick;
	}

	function onModeSelect(solo : Bool) : Void
	{
		setMode(solo ? LobbyMode.Solo : LobbyMode.Party);
	}

	function setMode(m : LobbyMode) : Void
	{
		if (mode == m) return;
		mode = m;
		playDesign.getModePanel().setActiveMode(mode == LobbyMode.Solo);
	}

	function onSearchClick() : Void
	{
		trace("SEARCH clicked, mode=" + mode);
	}
}