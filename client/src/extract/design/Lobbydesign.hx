package extract.design;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;

/**
	The lobby 2D HUD, built from the Lunacy design.
	Panels are drawn with rounded rects (h2d.Graphics) for faithful geometry;
	text/colors are styled by ui/lobby.css via domkit classes.

	NOTE: Oswald fonts are not in the repo yet, so text uses DefaultFont.
	Once Oswald .bfnt files exist, add `font: font/oswald-bold.bfnt 18;`
	(etc.) rules to the CSS classes below.
**/
class Lobbydesign extends Object
{
	// palette — mirror of :root in ui/lobby.css
	static inline var PANEL      = 0x1A1208;
	static inline var BORDER     = 0xC8956C;
	static inline var BORDER_ID  = 0x3A2A18;
	static inline var ACCENT     = 0xC4A44A;
	static inline var BTN        = 0x8B2010;
	static inline var BTN_BORDER = 0xA03020;
	static inline var DIM        = 0x6A5A3A;
	static inline var READY      = 0x1ACC19;
	static inline var WAITING    = 0xB3B319;
	static inline var NOTREADY   = 0xB33333;
	static inline var ICON_FILL  = 0x2A1A10;

	public function new()
	{
		super();
		buildModePanel();
		buildReadyPanel();
	}

	// rounded panel = Graphics background + a content container for children
	function makePanel(parent : Object, w : Int, h : Int, fill : Int, border : Int, radius : Int) : { root : Object, content : Object }
	{
		var root = new Object(parent);
		var g = new Graphics(root);
		g.beginFill(fill, 1);
		g.lineStyle(1, border, 1);
		g.drawRoundedRect(0, 0, w, h, radius);
		g.endFill();
		var content = new Object(root);
		return { root: root, content: content };
	}

	function label(parent : Object, x : Int, y : Int, w : Int, text : String, cls : String, center : Bool) : Text
	{
		var t = new Text(hxd.res.DefaultFont.get(), parent);
		t.text = text;
		t.x = x;
		t.y = y;
		t.maxWidth = w;
		if (center) t.textAlign = Center;
		t.textColor = colorFor(cls);
		return t;
	}

	static function colorFor(cls : String) : Int
	{
		return switch (cls)
		{
			case "mode-title": ACCENT;
			case "duration": DIM;
			case "mode-icon-label": 0xD8B98A;
			case "mode-icon-label-idle": DIM;
			case "search-text": 0xF0E0D0;
			case "ready-title": 0xBFBFBF;
			case "player-status-ready": READY;
			case "player-status-waiting": WAITING;
			case "player-status-notready": NOTREADY;
			default: 0xFFFFFF;
		};
	}

	function buildModePanel()
	{
		var p = makePanel(this, 300, 460, PANEL, BORDER, 6);
		p.root.x = 40; p.root.y = 40;

		label(p.content, 106, 15, 88, "GAME MODE", "mode-title", true);

		var map = new Graphics(p.content);
		map.beginFill(ICON_FILL, 1); map.lineStyle(1, BORDER_ID, 1);
		map.drawRoundedRect(60, 55, 180, 120, 4); map.endFill();

		label(p.content, 134, 185, 32, "30:00", "duration", true);

		var solo = makePanel(p.content, 56, 56, ICON_FILL, BORDER, 6);
		solo.root.x = 85; solo.root.y = 215;
		label(solo.content, 48, 0, 8, "1", "mode-icon-label", true);

		var party = makePanel(p.content, 56, 56, PANEL, BORDER_ID, 6);
		party.root.x = 159; party.root.y = 215;
		label(party.content, 45, 0, 11, "3", "mode-icon-label-idle", true);

		var btn = makePanel(p.content, 180, 50, BTN, BTN_BORDER, 4);
		btn.root.x = 60; btn.root.y = 290;
		label(btn.content, 60, 12, 59, "SEARCH", "search-text", true);
	}

	function buildReadyPanel()
	{
		var p = makePanel(this, 600, 190, PANEL, BORDER, 6);
		p.root.x = 380; p.root.y = 200;

		label(p.content, 296, 12, 48, "READY", "ready-title", true);

		var states = [
			{ s: "READY",    c: READY,    cls: "player-status-ready" },
			{ s: "WAITING",  c: WAITING,  cls: "player-status-waiting" },
			{ s: "NOT READY",c: NOTREADY, cls: "player-status-notready" },
		];
		for (i in 0...states.length)
		{
			var st = states[i];
			var chip = makePanel(p.content, 72, 104, PANEL, (i == 0 ? BORDER : BORDER_ID), 6);
			chip.root.x = 135 + i * (72 + 10);

			var ic = new Graphics(chip.content);
			ic.beginFill(ICON_FILL, 1); ic.lineStyle(1, (i == 0 ? BORDER : BORDER_ID), 1);
			ic.drawRoundedRect(12, 10, 48, 48, 4); ic.endFill();

			label(chip.content, 22, 86, 50, st.s, st.cls, true);
		}
	}
}
