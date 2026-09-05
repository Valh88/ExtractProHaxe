package extract.views;

import extract.utils.BaseScene;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;
import extract.design.ModePanel;
import extract.design.ReadyPanel;
import extract.design.TopPanel;
import extract.views.lobby.LobbyTab;
import extract.views.lobby.PlaySubView;
import extract.views.lobby.HeroesSubView;
import shared.events.EventBus;
import shared.events.GameEvents.SearchStarted;

class LobbyView extends BaseScene
{
	var design : Lobbydesign;
	var readyPanel : ReadyPanel;
	var topPanel : TopPanel;
	var bus : EventBus;
	var currentSubView : Null<SubView>; // SubView implements IUpdate
	var subViews : Map<LobbyTab, SubView> = new Map();
	var flyCam : phys.utils.CameraFly;

	public function new(s2d : Scene2D, style : Style, bus : EventBus)
	{
		super(s2d, style);
		this.bus = bus;
		flyCam = new phys.utils.CameraFly(camera);

		design = new Lobbydesign();
		attachUI(design);
		readyPanel = design.getReadyPanel();
		topPanel = design.getTopPanel();
		topPanel.onTabSelected = onTabSelected;

		bus.subscribe(SearchStarted, function(e : SearchStarted)
		{
			trace("SearchStarted: mode=" + e.mode);
			showReadyPanel();
		});

		switchSubView(LobbyTab.Play);
	}

	public function showReadyPanel() : Void readyPanel.show();
	public function hideReadyPanel() : Void readyPanel.hide();

	function attachUI(d : Lobbydesign)
	{
		s2d.addChild(d);
		style.addObject(d);
		style.sync();
	}

	public function switchSubView(tab : LobbyTab)
	{
		var sub = subViews.get(tab);
		if (sub == null)
		{
			sub = createSubView(tab);
			if (sub == null)
			{
				trace(tab + " sub-view not implemented yet");
				return;
			}
			subViews.set(tab, sub);
			var container = design.getSubViewDesign();
			container.addChild(sub.design);
			style.addObject(sub.design);
		}
		if (currentSubView == sub) return;

		if (currentSubView != null)
			currentSubView.design.visible = false;
		currentSubView = sub;
		sub.design.visible = true;
		topPanel.setActiveTab(tabIndex(tab));
		style.sync();
	}

	/** Tab click -> LobbyTab (index order == enum constructor order). */
	function onTabSelected(i : Int) : Void
	{
		switchSubView(Type.createEnumIndex(LobbyTab, i));
	}

	function tabIndex(tab : LobbyTab) : Int
	{
		return Type.enumIndex(tab);
	}

	function createSubView(tab : LobbyTab) : SubView
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
		flyCam.update(dt);
		super.update(dt);
		if (currentSubView != null)
			currentSubView.update(dt);
	}
}
