package extract.fsm;

/**
	Bus request to switch the gameplay FSM. A system/view publishes it on the
	shared bus; `extract.systems.GameplayFsm` subscribes and performs the
	transition (publishing a `StateChangeEvent` on completion).
**/
class GameplayStateRequest
{
	public var newState(default, null) : GameplayMode;

	public function new(newState : GameplayMode)
	{
		this.newState = newState;
	}
}