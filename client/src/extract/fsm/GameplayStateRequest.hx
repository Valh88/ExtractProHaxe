package extract.fsm;

/**
	Bus request to switch the gameplay state machine. A system/view publishes
	it on the shared bus; `extract.fsm.GameplayState` subscribes and performs
	the transition (publishing a `StateChangeEvent` on completion).
**/
class GameplayStateRequest
{
	public var newState(default, null) : GameplayMode;

	public function new(newState : GameplayMode)
	{
		this.newState = newState;
	}
}