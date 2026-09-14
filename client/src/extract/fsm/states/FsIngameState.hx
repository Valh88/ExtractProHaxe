package extract.fsm.states;

import extract.fsm.GameplayMode;
import extract.systems.GameplayFsm;
import shared.utils.fsm.AState;

/** Gameplay active: world sim + FPS look. Logic to be added later. */
class FsIngameState extends AState<GameplayMode>
{
	final fsm : GameplayFsm;

	public function new(fsm : GameplayFsm)
	{
		super();
		this.fsm = fsm;
	}
}