package extract.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.systems.System;
import shared.utils.fsm.StateMachine;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayStateRequest;
import extract.fsm.GameplayToggleRequest;
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
	final toggleHandler : GameplayToggleRequest -> Void;

	public function new(bus : EventBus, ?gd : GameData)
	{
		super(bus, null, gd, "GameplayFsm");
		requestHandler = onRequest;
		toggleHandler = onToggle;
		machine = new StateMachine<GameplayMode>(bus); // view bus — never create a new one
		machine.registerState(GameplayMode.fsIngame, new FsIngameState(this));
		machine.registerState(GameplayMode.fsSettings, new FsSettingsState(this));
		// any system can request a transition by publishing GameplayStateRequest
		// or a flip by publishing GameplayToggleRequest (ESC-style)
		bus.subscribe(GameplayStateRequest, requestHandler);
		bus.subscribe(GameplayToggleRequest, toggleHandler);
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

	/** Switch to `mode` (publishes a StateChangeEvent on the view bus). */
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

	override public function update(dt : Float) : Void
	{
		machine.update(dt);
	}

	override public function dispose() : Void
	{
		bus.unsubscribe(GameplayStateRequest, requestHandler);
		bus.unsubscribe(GameplayToggleRequest, toggleHandler);
		machine.dispose();
	}
}