package extract.fsm.states;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import shared.utils.fsm.AState;

/** Settings open: menu + tabs. Logic to be added later. */
class FsSettingsState extends AState<GameplayMode>
{
	final fsm : GameplayState;

	public function new(fsm : GameplayState)
	{
		super();
		this.fsm = fsm;
	}
}