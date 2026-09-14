package shared.utils.fsm;

/**
	Abstract base class for a single state used by `StateMachine`.

	Overridable hooks — called by the machine on transitions:
	- `enter`   — state becomes active
	- `update`  — ticked every frame while active
	- `exit`    — state is being left
	- `changeState` — optional hook for a state to request a transition itself
**/
class AState<T>
{
	public function new() {}

	/** Called when entering this state. `fromState` is the state we came from. */
	public function enter(fromState : T) : Void {}

	/** Called every frame while this state is active. */
	public function update(dt : Float) : Void {}

	/** Called when leaving this state. `toState` is where we are going. */
	public function exit(toState : T) : Void {}

	/**
		Hook to request a transition from inside the state.
		Override to route to the owning machine.
	**/
	public function changeState(newState : T) : Void {}
}