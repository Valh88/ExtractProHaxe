package extract.views;

import extract.utils.BaseScene;
import extract.utils.SubView;
import extract.utils.SubViewSwitcher;
import extract.systems.DebugCameraSystem;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;
import extract.design.ReadyPanel;
import extract.design.TopPanel;
import extract.views.lobby.LobbyTab;
import extract.views.lobby.PlaySubView;
import extract.views.lobby.HeroesSubView;
import shared.events.EventBus;
import shared.events.GameEvents.SearchStarted;
import shared.GameData;

class LobbyView extends BaseScene
{
	var design : Lobbydesign;
	var readyPanel : ReadyPanel;
	var topPanel : TopPanel;
	var subSwitcher : SubViewSwitcher<LobbyTab>;

	public function new(s2d : Scene2D, style : Style, gd : GameData, bus : EventBus)
	{
		super(s2d, style, gd, bus);

		// debug fly camera as a presentation system (WASD/QE/Shift/RMB)
		systems.add(new DebugCameraSystem(bus, camera));

		design = new Lobbydesign();
		attachUI(design);
		readyPanel = design.getReadyPanel();
		topPanel = design.getTopPanel();
		topPanel.onTabSelected = onTabSelected;

		subSwitcher = new SubViewSwitcher<LobbyTab>(createSubView, attachSubView,
			function(tab : LobbyTab) topPanel.setActiveTab(Type.enumIndex(tab)));

		bus.subscribe(SearchStarted, function(e : SearchStarted)
		{
			trace("SearchStarted: mode=" + e.mode);
			showReadyPanel();
		});

		subSwitcher.switchTo(LobbyTab.Play);
	}

	public function showReadyPanel() : Void readyPanel.show();
	public function hideReadyPanel() : Void readyPanel.hide();

	function attachUI(d : Lobbydesign)
	{
		s2d.addChild(d);
		style.addObject(d);
		style.sync();
	}

	/** Fresh sub-view: container addChild + domkit style registration. */
	function attachSubView(sub : SubView<Dynamic>) : Void
	{
		design.getSubViewDesign().addChild(sub.design);
		style.addObject(sub.design);
	}

	/** Tab click -> LobbyTab (index order == enum constructor order). */
	function onTabSelected(i : Int) : Void
	{
		subSwitcher.switchTo(Type.createEnumIndex(LobbyTab, i));
	}

	function createSubView(tab : LobbyTab) : Null<SubView<Dynamic>>
	{
		return switch (tab)
		{
			case Play: new PlaySubView(bus);
			case Heroes: new HeroesSubView(bus);
			case Inventory, Market: null; // not implemented yet
		}
	}

	public function addModel(o : h3d.scene.Object)
	{
		this.addChild(o);
	}

	override public function update(dt : Float)
	{
		super.update(dt);
		subSwitcher.update(dt);
	}
}
