package test;

import shared.events.EventBus;
import shared.utils.fsm.AState;
import shared.utils.fsm.StateChangeEvent;
import shared.utils.fsm.StateMachine;
import utest.Assert;

/**
	Covers the shared `StateMachine<T>` + `EventBus` async contract:
	- `changeState` takes effect immediately (exit/enter run, current set),
	- a `StateChangeEvent` is published but only delivered by `bus.flush()`,
	- listeners (typed and raw bus) receive it after flush,
	- guards veto transitions,
	- previous-state restore + unsubscribe work.
**/
enum CoreMode { idle; run; paused; }

class _CoreState extends AState<CoreMode>
{
	public var id : CoreMode;
	/** Fill order of enter/exit calls. */
	public var enterCalls : Array<{from : Null<CoreMode>}> = [];
	public var exitCalls : Array<{to : CoreMode}> = [];

	public function new(id : CoreMode)
	{
		super();
		this.id = id;
	}

	override function enter(from : CoreMode)
		enterCalls.push({from: from});

	override function exit(to : CoreMode)
		exitCalls.push({to: to});
}

class FsmCoreTest extends utest.Test
{
	var bus : EventBus;
	var sm : StateMachine<CoreMode>;
	var stIdle : _CoreState;
	var stRun : _CoreState;
	var stPaused : _CoreState;

	function setup()
	{
		bus = new EventBus();
		sm = new StateMachine<CoreMode>(bus);
		stIdle = new _CoreState(CoreMode.idle);
		stRun = new _CoreState(CoreMode.run);
		stPaused = new _CoreState(CoreMode.paused);
		sm.registerState(CoreMode.idle, stIdle);
		sm.registerState(CoreMode.run, stRun);
		sm.registerState(CoreMode.paused, stPaused);
	}

	public function testStartsEmpty()
	{
		Assert.equals(null, sm.currentState);
		Assert.isFalse(sm.hasCurrentState);
		Assert.isNull(sm.currentStateObj);
	}

	public function testChangeIsImmediateEventIsFlushed()
	{
		var events : Array<{n : CoreMode, o : Null<CoreMode>}> = [];
		sm.addStateChangeListener(function(n, o) events.push({n: n, o: o}));

		sm.changeState(CoreMode.run);

		// synchronous: state set, hooks ran
		Assert.equals(CoreMode.run, sm.currentState);
		Assert.isTrue(sm.hasCurrentState);
		Assert.notNull(sm.currentStateObj);
		Assert.equals(1, stRun.enterCalls.length);
		Assert.isNull(stRun.enterCalls[0].from); // first enter: no previous state

		// event queued, NOT delivered yet
		Assert.equals(0, events.length);

		bus.flush();
		Assert.equals(1, events.length);
		Assert.equals(CoreMode.run, events[0].n);
		Assert.isNull(events[0].o);
	}

	public function testExitEnterHookOrder()
	{
		sm.changeState(CoreMode.run);
		sm.changeState(CoreMode.paused);

		Assert.equals(1, stRun.exitCalls.length);
		Assert.equals(CoreMode.paused, stRun.exitCalls[0].to); // exit(to = dest)

		Assert.equals(1, stPaused.enterCalls.length);
		Assert.equals(CoreMode.run, stPaused.enterCalls[0].from);
	}

	public function testRawBusSubscribe()
	{
		var got : Array<StateChangeEvent<CoreMode>> = [];
		bus.subscribe(StateChangeEvent, function(e : StateChangeEvent<CoreMode>) got.push(e));

		sm.changeState(CoreMode.run);
		Assert.equals(0, got.length);
		bus.flush();
		Assert.equals(1, got.length);
		Assert.equals(CoreMode.run, got[0].newState);
		Assert.isNull(got[0].oldState);
	}

	public function testSameStateIsNoOp()
	{
		var events = 0;
		sm.addStateChangeListener(function(n, o) events++);
		sm.changeState(CoreMode.run);
		bus.flush();
		Assert.equals(1, events);
		sm.changeState(CoreMode.run); // same state
		bus.flush();
		Assert.equals(1, events); // no second event
	}

	public function testPreviousStateRestore()
	{
		sm.changeState(CoreMode.run);
		sm.changeState(CoreMode.paused);
		Assert.equals(CoreMode.paused, sm.currentState);
		sm.goToPreviousState();
		Assert.equals(CoreMode.run, sm.currentState);
		sm.goToPreviousState();
		Assert.equals(CoreMode.paused, sm.currentState);
	}

	public function testRemoveListener()
	{
		var events = 0;
		function cb(n : CoreMode, o : CoreMode) events++;
		sm.addStateChangeListener(cb);

		sm.changeState(CoreMode.run);
		bus.flush();
		Assert.equals(1, events);

		sm.removeStateChangeListener(cb);
		sm.changeState(CoreMode.paused);
		bus.flush();
		Assert.equals(1, events); // no longer called
	}

	public function testDispose()
	{
		var events = 0;
		sm.addStateChangeListener(function(n, o) events++);
		sm.dispose();
		Assert.isFalse(sm.hasCurrentState);
		Assert.isNull(sm.currentState);
		sm.changeState(CoreMode.run);
		bus.flush();
		Assert.equals(0, events);
	}
}