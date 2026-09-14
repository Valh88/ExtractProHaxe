package extract.fsm.states;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import shared.utils.fsm.AState;

/** Gameplay active: world sim + FPS look. Logic to be added later. */
class FsIngameState extends AState<GameplayMode>
{
	final fsm : GameplayState;

	public function new(fsm : GameplayState)
	{
		super();
		this.fsm = fsm;
	}
}