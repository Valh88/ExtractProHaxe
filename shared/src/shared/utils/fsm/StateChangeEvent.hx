package shared.utils.fsm;

/** Payload published on `EventBus` when the machine switches state. */
class StateChangeEvent<T>
{
	public var newState(default, null) : T;
	public var oldState(default, null) : T;

	public function new(newState : T, oldState : T)
	{
		this.newState = newState;
		this.oldState = oldState;
	}
}