package extract.fsm;

/**
	Bus request to FLIP the gameplay FSM (ESC-style toggle). The FSM decides
	the target state from its own `current` — the publisher needs no state
	knowledge. Use `GameplayStateRequest` when a state must be forced.
**/
class GameplayToggleRequest
{
	public function new() {}
}