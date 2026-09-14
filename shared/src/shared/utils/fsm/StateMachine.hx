package shared.utils.fsm;

/** Callback invoked on state change: `(newState, oldState)`. */
typedef StateChangeCallback<T> = (newState : T, oldState : T) -> Void;

/**
	Generic state machine.

	Manages a set of `AState<T>` instances and transitions between them,
	guaranteeing `exit`/`enter` on every `changeState`.

	`T` is the state identifier type (enum, Int or String).
**/
class StateMachine<T>
{
	var states : Array<{ id : T, obj : AState<T> }> = [];
	var listeners : Array<StateChangeCallback<T>> = [];

	/** Current state id (null until the first change). */
	public var currentState(default, null) : Null<T>;

	/** The state that was current before the last change. */
	public var previousState(default, null) : Null<T>;

	/** True once a first state has been activated. */
	public var hasCurrentState(default, null) : Bool = false;

	/** The active state object, or null if none. */
	public var currentStateObj(get, null) : Null<AState<T>>;

	/** When true, `changeState` is ignored. */
	public var isLocked : Bool = false;

	/** When true, `update` is a no-op. */
	public var paused : Bool = false;

	public function new()
	{
	}

	function get_currentStateObj() : Null<AState<T>>
	{
		return hasCurrentState ? getState(currentState) : null;
	}

	function indexOf(stateId : T) : Int
	{
		for (i in 0...states.length)
			if (states[i].id == stateId) return i;
		return -1;
	}

	/** Register (or replace) a state object under `stateId`. */
	public function registerState(stateId : T, stateObj : AState<T>) : Void
	{
		var i = indexOf(stateId);
		if (i >= 0)
			states[i].obj = stateObj;
		else
			states.push({ id : stateId, obj : stateObj });
	}

	/** Get a registered state object, or null. */
	public function getState(stateId : T) : Null<AState<T>>
	{
		var i = indexOf(stateId);
		return i >= 0 ? states[i].obj : null;
	}

	/** True if `stateId` has a registered state object. */
	public function hasState(stateId : T) : Bool
	{
		return indexOf(stateId) >= 0;
	}

	/**
		Switch to `newState`. Calls `exit` on the current state and `enter` on
		the new one, then notifies listeners. No-op if already in that state
		or if the machine is locked.
	**/
	public function changeState(newState : T) : Void
	{
		if (isLocked) return;
		if (hasCurrentState && newState == currentState) return;

		var oldState = currentState;

		if (hasCurrentState)
		{
			var oldObj = getState(oldState);
			if (oldObj != null) oldObj.exit(newState);
		}

		previousState = oldState;
		currentState = newState;
		hasCurrentState = true;

		var newObj = getState(newState);
		if (newObj != null) newObj.enter(oldState);

		for (cb in listeners.copy())
			cb(newState, oldState);
	}

	/** Tick the current state. Call once per frame. */
	public function update(dt : Float) : Void
	{
		if (paused || !hasCurrentState) return;

		var obj = getState(currentState);
		if (obj != null) obj.update(dt);
	}

	/** Subscribe to state changes. */
	public function addStateChangeListener(cb : StateChangeCallback<T>) : Void
	{
		listeners.push(cb);
	}

	/** Remove a previously added change listener. */
	public function removeStateChangeListener(cb : StateChangeCallback<T>) : Void
	{
		listeners.remove(cb);
	}

	/** Return to the previous state (no-op before the first change). */
	public function goToPreviousState() : Void
	{
		if (hasCurrentState && previousState != null)
			changeState(previousState);
	}

	/** Drop all states and listeners. */
	public function dispose() : Void
	{
		states = [];
		listeners = [];
		hasCurrentState = false;
		currentState = null;
		previousState = null;
	}
}