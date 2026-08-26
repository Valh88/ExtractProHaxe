package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;
import extract.design.Lobbydesign;
import extract.design.ModePanel;
import extract.views.CSS;
import extract.views.lobby.PlaySubView;

class LobbyView extends Scene3D
{
	var style : Style;
	var s2d : Scene2D;
	var design : Lobbydesign;
	var currentSubView : Null<PlaySubView>;

	static var LOBBY_CSS = CSS.LOBBY_CSS;

	public function new(s2d : Scene2D)
	{
		super();
		this.s2d = s2d;
		h3d.Engine.getCurrent().backgroundColor = 0x0D0D0D;
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);
		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, -0.4, -1), this);
		light.power = 2;
		light.isMainLight = true;
		light.shadows.mode = h3d.pass.Shadows.RenderMode.Dynamic;
		light.shadows.size = 2048;
		light.shadows.power = 150;
		light.shadows.bias *= 0.3;

		design = new Lobbydesign();
		attachUI(design);
		switchSubView(new PlaySubView());
	}

	function attachUI(d : Lobbydesign)
	{
		style = new Style();
		style.add(style.cssParser.parseSheet(LOBBY_CSS, "ui/lobby.css"));
		s2d.addChild(d);
		style.addObject(d);
		style.sync();
	}

	public function switchSubView(sub : PlaySubView)
	{
		var container = design.getSubView();
		if (currentSubView != null)
			container.removeChild(currentSubView.design);
		currentSubView = sub;
		container.addChild(sub.design);
		style.addObject(sub.design);
		style.sync();
	}

	public function addModel(o : h3d.scene.Object)
	{
		this.addChild(o);
	}

	public function update(dt : Float)
	{
		style.sync(dt);
	}
}
