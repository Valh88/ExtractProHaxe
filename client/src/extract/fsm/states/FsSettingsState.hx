package extract.fsm.states;

import extract.fsm.GameplayMode;
import extract.systems.GameplayFsm;
import shared.utils.fsm.AState;

/** Settings open: menu + tabs. Logic to be added later. */
class FsSettingsState extends AState<GameplayMode>
{
	final fsm : GameplayFsm;

	public function new(fsm : GameplayFsm)
	{
		super();
		this.fsm = fsm;
	}
}