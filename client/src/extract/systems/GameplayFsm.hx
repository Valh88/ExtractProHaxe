package extract.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;
import shared.utils.fsm.StateMachine;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayStateRequest;
import extract.fsm.states.FsIngameState;
import extract.fsm.states.FsSettingsState;

/**
	Client-side gameplay state machine as a visual `System`.

	Owns a `StateMachine<GameplayMode>` built on the VIEW's event bus — no new
	bus is created. Every `changeState` publishes a `StateChangeEvent` on that
	bus (delivered by `bus.flush()` at end of frame in HeapsApp), so other
	systems/views can react via `onState(...)` or a raw
	`bus.subscribe(StateChangeEvent, ...)`.

	Extending: add a `GameplayMode` case, an `AState` subclass and one
	`registerState` call. Behaviour goes into the state's enter/update/exit.
**/
class GameplayFsm extends System
{
	/** The underlying state machine (public for advanced use / listeners). */
	public var machine(default, null) : StateMachine<GameplayMode>;

	/** Current state id, null until the first transition. */
	public var current(get, never) : Null<GameplayMode>;

	// held reference: HL creates a NEW closure on every `this.onRequest`
	// access, and EventBus.unsubscribe matches handlers via
	// Reflect.compareMethods — reuse the SAME closure for sub/unsub
	final requestHandler : GameplayStateRequest -> Void;

	public function new(bus : EventBus, ?gd : GameData)
	{
		super(bus, null, gd, "GameplayFsm");
		requestHandler = onRequest;
		machine = new StateMachine<GameplayMode>(bus); // view bus — never create a new one
		machine.registerState(GameplayMode.fsIngame, new FsIngameState(this));
		machine.registerState(GameplayMode.fsSettings, new FsSettingsState(this));
		// any system can request a transition by publishing GameplayStateRequest
		bus.subscribe(GameplayStateRequest, requestHandler);
	}

	function onRequest(e : GameplayStateRequest) : Void
	{
		changeState(e.newState);
	}

	function get_current() : Null<GameplayMode>
		return machine.currentState;

	/** Switch to `mode` (publishes a StateChangeEvent on the view bus). */
	public function changeState(mode : GameplayMode) : Void
	{
		machine.changeState(mode);
	}

	/** Toggle between the registered states (no-op before the first one). */
	public function toggle() : Void
	{
		if (!machine.hasCurrentState) return;
		machine.changeState(machine.currentState == GameplayMode.fsIngame
			? GameplayMode.fsSettings : GameplayMode.fsIngame);
	}

	/** Typed state-change listener: `(newState, oldState)` — convenience. */
	public function onState(cb : (newState : GameplayMode, oldState : GameplayMode) -> Void) : Void
	{
		machine.addStateChangeListener(cb);
	}

	override public function update(dt : Float) : Void
	{
		machine.update(dt);
	}

	override public function dispose() : Void
	{
		bus.unsubscribe(GameplayStateRequest, requestHandler);
		machine.dispose();
	}
}