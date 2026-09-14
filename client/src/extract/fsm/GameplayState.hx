package extract.fsm;

import shared.events.EventBus;
import shared.utils.fsm.StateMachine;

import extract.fsm.states.FsIngameState;
import extract.fsm.states.FsSettingsState;

/**
	Client gameplay state machine as a process-wide GLOBAL singleton.

	ANY code can query the current gameplay mode via `GameplayState.get().current`
	(settings menu visibility, input freeze switch, ...). Transitions arrive as
	bus requests (`GameplayStateRequest` / `GameplayToggleRequest`, delivered on
	`bus.flush()` at end of frame) or as direct `changeState` / `toggle` calls;
	every change publishes a `StateChangeEvent` on the SAME bus the machine was
	built on, so systems/views react loosely (`bus.subscribe(StateChangeEvent, ...)`).

	Business rule: the machine is not a per-scene `System` — it is a process-wide
	singleton wired by `GameplayState.init(bus)` and ticked once a frame from
	`GamePlayView.update`, outliving scene switches (any system/view can query
	`GameplayState.get().current` without holding a reference).

	Extending: add a `GameplayMode` case, an `AState` subclass and one
	`registerState` call. Behaviour goes into the state's enter/update/exit.
**/
class GameplayState
{
	static var inst : GameplayState;

	/** The bus the machine publishes `StateChangeEvent` on (the app bus). */
	final bus : EventBus;

	/** The underlying state machine (public for advanced use / listeners). */
	public var machine(default, null) : StateMachine<GameplayMode>;

	/** Current state id, null until the first transition. */
	public var current(get, never) : Null<GameplayMode>;

	var disposed : Bool = false;

	// held reference: HL creates a NEW closure on every `this.onRequest`
	// access, and EventBus.unsubscribe matches handlers via
	// Reflect.compareMethods — reuse the SAME closure for sub/unsub
	final requestHandler : GameplayStateRequest -> Void;
	final toggleHandler : GameplayToggleRequest -> Void;

	function new(bus : EventBus)
	{
		this.bus = bus;
		requestHandler = onRequest;
		toggleHandler = onToggle;
		machine = new StateMachine<GameplayMode>(bus); // app bus — never create a new one
		machine.registerState(GameplayMode.fsIngame, new FsIngameState(this));
		machine.registerState(GameplayMode.fsSettings, new FsSettingsState(this));
		// any system can request a transition by publishing GameplayStateRequest
		// or a flip by publishing GameplayToggleRequest (ESC-style)
		bus.subscribe(GameplayStateRequest, requestHandler);
		bus.subscribe(GameplayToggleRequest, toggleHandler);
	}

	/** Create / replace the singleton wired to `bus` (call once in GamePlayView). */
	public static function init(bus : EventBus) : GameplayState
	{
		if (inst != null) inst.dispose();
		inst = new GameplayState(bus);
		return inst;
	}

	public static function get() : GameplayState
	{
		if (inst == null)
			throw "GameplayState.get() before init(bus) — call GameplayState.init() from GamePlayView";
		return inst;
	}

	function onRequest(e : GameplayStateRequest) : Void
	{
		changeState(e.newState);
	}

	function onToggle(e : GameplayToggleRequest) : Void
	{
		toggle();
	}

	function get_current() : Null<GameplayMode>
		return machine.currentState;

	/** Switch to `mode` (publishes a StateChangeEvent on the app bus). */
	public function changeState(mode : GameplayMode) : Void
	{
		machine.changeState(mode);
	}

	/** Flip between the registered states (ESC-style). Before the first
		transition the machine is implicitly fsIngame (gameplay starts in-game),
		so the VERY first toggle opens the settings instead of being a no-op. */
	public function toggle() : Void
	{
		if (!machine.hasCurrentState)
		{
			machine.changeState(GameplayMode.fsSettings);
			return;
		}
		machine.changeState(machine.currentState == GameplayMode.fsIngame
			? GameplayMode.fsSettings : GameplayMode.fsIngame);
	}

	/** Typed state-change listener: `(newState, oldState)` — convenience. */
	public function onState(cb : (newState : GameplayMode, oldState : GameplayMode) -> Void) : Void
	{
		machine.addStateChangeListener(cb);
	}

	/** Tick the active state. Called from `GamePlayView.update`. */
	public function update(dt : Float) : Void
	{
		machine.update(dt);
	}

	/** Unsubscribe from the bus + dispose the machine. Idempotent. */
	public function dispose() : Void
	{
		if (disposed) return;
		disposed = true;
		if (inst == this) inst = null;
		bus.unsubscribe(GameplayStateRequest, requestHandler);
		bus.unsubscribe(GameplayToggleRequest, toggleHandler);
		machine.dispose();
	}
}