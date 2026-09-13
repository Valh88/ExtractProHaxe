package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

@:uiComp("settings-design")
class SettingsDesign extends Flow implements Object
{
	static var SRC =
		<settings-design class="settings-root">
			<flow class="settings-overlay" x="0" y="0">
				<flow id="panel" class="settings-panel" x="660" y="170">
					<text id="title" class="settings-title" x="0" y="35"/>
					<flow id="divider" class="settings-divider" x="60" y="150"/>
					<!-- tabs -->
					<flow id="tabsWrap" class="settings-tabs" x="50" y="106">
						<flow id="tabAudio" class="settings-tab" x="0" y="0">
							<text id="tabAudioTxt" class="settings-tab-text" x="0" y="0"/>
						</flow>
						<flow id="tabDisplay" class="settings-tab" x="130" y="0">
							<text id="tabDisplayTxt" class="settings-tab-text" x="0" y="0"/>
						</flow>
						<flow id="tabControls" class="settings-tab" x="260" y="0">
							<text id="tabControlsTxt" class="settings-tab-text" x="0" y="0"/>
						</flow>
						<flow id="tabGameplay" class="settings-tab" x="390" y="0">
							<text id="tabGameplayTxt" class="settings-tab-text" x="0" y="0"/>
						</flow>
						<flow id="tabIndicator" class="settings-tab-indicator" x="0" y="38"/>
					</flow>
					<!-- content slot: inlined content panels -->
					<flow id="contentAudio" class="settings-content" x="40" y="170"/>
					<flow id="contentDisplay" class="settings-content" x="40" y="170"/>
					<flow id="contentControls" class="settings-content" x="40" y="170"/>
					<flow id="contentGameplay" class="settings-content" x="40" y="170"/>
					<!-- buttons -->
					<flow id="saveBtn" class="settings-btn-save" x="40" y="670">
						<text id="saveTxt" class="settings-btn-text" x="0" y="0"/>
					</flow>
					<flow id="backBtn" class="settings-btn-back" x="280" y="670">
						<text id="backTxt" class="settings-btn-text" x="0" y="0"/>
					</flow>
				</flow>
			</flow>
		</settings-design>;

	public var onBack : Null<Void -> Void>;
	public var onSave : Null<Void -> Void>;

	var tabs : Array<Flow>;
	var contents : Array<Flow>;
	var tabTxts : Array<h2d.Text>;
	var activeTab : Int = 0;

	public function new(?parent)
	{
		super(parent);
		initComponent();

		title.text = "SETTINGS";

		tabAudioTxt.text = "AUDIO";
		tabDisplayTxt.text = "DISPLAY";
		tabControlsTxt.text = "CONTROLS";
		tabGameplayTxt.text = "GAMEPLAY";

		saveTxt.text = "SAVE";
		backTxt.text = "BACK";

		tabs = [tabAudio, tabDisplay, tabControls, tabGameplay];
		contents = [contentAudio, contentDisplay, contentControls, contentGameplay];
		tabTxts = [tabAudioTxt, tabDisplayTxt, tabControlsTxt, tabGameplayTxt];

		for (i in 0...4)
		{
			var idx = i;
			var t = tabs[i];
			t.enableInteractive = true;
			t.interactive.cursor = Button;
			t.interactive.onClick = function(_) setTab(idx);
		}

		saveBtn.enableInteractive = true;
		saveBtn.interactive.cursor = Button;
		saveBtn.interactive.onClick = function(_) if (onSave != null) onSave();

		backBtn.enableInteractive = true;
		backBtn.interactive.cursor = Button;
		backBtn.interactive.onClick = function(_) if (onBack != null) onBack();

		setTab(0);
	}

	public function setTab(idx : Int) : Void
	{
		if (idx < 0 || idx > 3) return;

		// hide old content
		if (contents[activeTab] != null) contents[activeTab].visible = false;

		activeTab = idx;

		// show new content
		if (contents[activeTab] != null) contents[activeTab].visible = true;

		// update tab styles
		for (i in 0...4)
		{
			if (i == idx)
			{
				tabs[i].dom.addClass("settings-tab-active");
				tabTxts[i].color = 0xC4A44A;
			}
			else
			{
				tabs[i].dom.removeClass("settings-tab-active");
				tabTxts[i].color = 0x737373;
			}
		}

		// move indicator
		tabIndicator.x = tabs[idx].x;
	}

	public function getContent(idx : Int) : Flow
	{
		return contents[idx];
	}
}
