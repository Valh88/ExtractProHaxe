package extract.views.lobby;

import extract.design.ModePanel;

class PlaySubView
{
	public var panel : ModePanel;

	public function new()
	{
		panel = new ModePanel();
		panel.setPosition(40, 140);
	}
}
