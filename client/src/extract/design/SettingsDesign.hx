package extract.design;

import h2d.Flow;
import h2d.Graphics;
import h2d.Interactive;
import h2d.domkit.Object;

@:uiComp("settings-design")
class SettingsDesign extends Flow implements Object
{
	static var SRC =
		<settings-design class="settings-root">
			<flow id="overlay" class="settings-overlay" x="0" y="0"/>
			<flow id="panel" class="settings-panel" x="660" y="170">
				<text id="title" class="settings-title" x="200" y="35"/>
				<flow id="divider" class="settings-divider" x="60" y="150"/>
				<flow id="tabsWrap" class="settings-tabs-wrap" x="50" y="106">
					<text id="tabAudio" class="settings-tab" x="10" y="0"/>
					<text id="tabDisplay" class="settings-tab" x="140" y="0"/>
					<text id="tabControls" class="settings-tab" x="270" y="0"/>
					<text id="tabGameplay" class="settings-tab" x="400" y="0"/>
				</flow>
				<flow id="contentWrap" class="settings-content-wrap" x="60" y="160"/>
			</flow>
			<flow id="saveBtn" class="settings-btn-save" x="700" y="920">
				<text id="saveTxt" class="settings-btn-text" x="82" y="12"/>
			</flow>
			<flow id="backBtn" class="settings-btn-back" x="1015" y="920">
				<text id="backTxt" class="settings-btn-text" x="80" y="12"/>
			</flow>
		</settings-design>;

	public var onBack : Null<Void -> Void>;
	public var onSave : Null<Void -> Void>;
	public var onTabClick : Null<Int -> Void>;

	var tabTxts : Array<h2d.Text>;
	var tabUnderlines : Array<h2d.Graphics>;
	var tabBgs : Array<h2d.Graphics>;
	var activeTab : Int = 0;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		title.text = "SETTINGS";

		var og = new Graphics();
		og.beginFill(0x000000, 0.3);
		og.drawRect(0, 0, 1920, 1080);
		og.endFill();
		overlay.addChildAt(og, 0);

		var pg = new Graphics();
		pg.beginFill(0xC8956C);
		pg.drawRoundedRect(0, 0, 600, 740, 8);
		pg.endFill();
		pg.beginFill(0x1A1A1A);
		pg.drawRoundedRect(2, 2, 596, 736, 6);
		pg.endFill();
		panel.addChildAt(pg, 0);

		var dg = new Graphics();
		dg.beginFill(0x99C8956C);
		dg.drawRect(0, 0, 480, 2);
		dg.endFill();
		divider.addChild(dg);

		tabAudio.text = "AUDIO";
		tabDisplay.text = "DISPLAY";
		tabControls.text = "CONTROLS";
		tabGameplay.text = "GAMEPLAY";

		tabTxts = [tabAudio, tabDisplay, tabControls, tabGameplay];

		var tabX = [0.0, 130.0, 260.0, 390.0];
		tabUnderlines = [];
		tabBgs = [];
		for (i in 0...4)
		{
			var g = new Graphics();
			g.beginFill(0xC4A44A);
			g.drawRect(0, 0, 110, 2);
			g.endFill();
			g.setPosition(tabX[i], 28);
			g.scaleX = 0;
			tabsWrap.addChild(g);
			tabsWrap.getProperties(g).isAbsolute = true;
			tabUnderlines.push(g);

			var bg = new Graphics();
			bg.beginFill(0x241C14);
			bg.drawRoundedRect(0, 0, 130, 34, 4);
			bg.endFill();
			bg.setPosition(tabX[i] - 10, 0);
			bg.visible = false;
			tabsWrap.addChildAt(bg, 0);
			tabsWrap.getProperties(bg).isAbsolute = true;
			tabBgs.push(bg);
		}

		saveTxt.text = "SAVE";
		backTxt.text = "BACK";

		var sg = new Graphics();
		sg.beginFill(0xA03020);
		sg.drawRoundedRect(0, 0, 200, 50, 4);
		sg.endFill();
		sg.beginFill(0x8B2010);
		sg.drawRoundedRect(2, 2, 196, 46, 3);
		sg.endFill();
		saveBtn.addChildAt(sg, 0);

		var bg = new Graphics();
		bg.beginFill(0x403828);
		bg.drawRoundedRect(0, 0, 200, 50, 4);
		bg.endFill();
		bg.beginFill(0x28201A);
		bg.drawRoundedRect(2, 2, 196, 46, 3);
		bg.endFill();
		backBtn.addChildAt(bg, 0);

		var hitX = [0, 130, 260, 390];
		var hitW = [130, 130, 130, 130];
		for (i in 0...4)
		{
			var idx = i;
			var hit = new h2d.Interactive(hitW[i], 30, tabsWrap);
			hit.setPosition(hitX[i], 0);
			hit.cursor = Button;
			tabsWrap.getProperties(hit).isAbsolute = true;
			hit.onClick = function(_) {
				if (onTabClick != null) onTabClick(idx);
			};
		}

		saveBtn.enableInteractive = true;
		saveBtn.interactive.cursor = Button;
		saveBtn.interactive.onClick = function(_) if (onSave != null) onSave();

		backBtn.enableInteractive = true;
		backBtn.interactive.cursor = Button;
		backBtn.interactive.onClick = function(_) if (onBack != null) onBack();

		setTab(0);
	}

	public function getContentWrap() : h2d.Flow return contentWrap;

	public function setTab(idx : Int) : Void
	{
		if (idx < 0 || idx > 3) return;
		activeTab = idx;

		for (i in 0...4)
		{
			if (tabTxts[i] == null) continue;
			tabTxts[i].dom.addClass(i == idx ? "settings-tab-active" : "settings-tab-idle");
			tabTxts[i].dom.removeClass(i == idx ? "settings-tab-idle" : "settings-tab-active");
			tabUnderlines[i].scaleX = (i == idx) ? 1.0 : 0.0;
			tabBgs[i].visible = (i == idx);
		}
	}
}
