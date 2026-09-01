package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;
import extract.design.ModePanel;
import extract.design.ReadyPanel;
import extract.IScene;
import extract.views.lobby.LobbyTab;
import extract.views.lobby.PlaySubView;
import extract.views.lobby.HeroesSubView;
import shared.events.EventBus;
import shared.events.GameEvents.SearchStarted;

class LobbyView extends Scene3D implements IScene
{
	var style : Style;
	var s2d : Scene2D;
	var design : Lobbydesign;
	var readyPanel : ReadyPanel;
	var bus : EventBus;
	var currentSubView : Null<SubView>;
	var subViews : Map<LobbyTab, SubView> = new Map();
	var flyCam : phys.utils.CameraFly;

	public function new(s2d : Scene2D, style : Style, bus : EventBus)
	{
		super();
		this.s2d = s2d;
		this.style = style;
		this.bus = bus;
		//h3d.Engine.getCurrent().backgroundColor = 0x0D0D0D;
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);
		flyCam = new phys.utils.CameraFly(camera);
		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, -0.4, -1), this);
		light.power = 2;
		light.isMainLight = true;
		light.shadows.mode = h3d.pass.Shadows.RenderMode.Dynamic;
		light.shadows.size = 2048;
		light.shadows.power = 150;
		light.shadows.bias *= 0.3;

		design = new Lobbydesign();
		attachUI(design);
		readyPanel = design.getReadyPanel();

		// SEARCH event -> show the ready panel
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
			if (sub == null) return;
			subViews.set(tab, sub);
		}

		var container = design.getSubView();
		if (currentSubView != null)
			container.removeChild(currentSubView.design);
		currentSubView = sub;
		container.addChild(sub.design);
		style.addObject(sub.design);
		style.sync();
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

	public function update(dt : Float)
	{
		flyCam.update(dt);
		style.sync(dt);
	}
}
