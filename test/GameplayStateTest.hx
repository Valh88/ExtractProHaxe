package test;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import extract.fsm.GameplayStateRequest;
import extract.fsm.GameplayToggleRequest;
import shared.events.EventBus;
import shared.utils.fsm.StateChangeEvent;
import utest.Assert;

/**
	Integration test of the client gameplay state singleton
	(`extract.fsm.GameplayState`) against a real `EventBus`: the full async
	request→flush→confirm round trip, toggle, duplicate-request no-op and
	dispose cleanup.
**/
class GameplayStateTest extends utest.Test
{
	var bus : EventBus;
	var state : GameplayState;
	var transitions : Array<{n : GameplayMode, o : GameplayMode}> = [];

	function setup()
	{
		bus = new EventBus();
		state = GameplayState.init(bus);
		transitions.resize(0);
		state.onState(function(n, o) transitions.push({n: n, o: o}));
	}

	function teardown()
	{
		state.dispose(); // also clears the static singleton
	}

	public function testStartsWithoutState()
	{
		Assert.isNull(state.current);
		Assert.isNull(state.machine.currentState);
		Assert.isFalse(state.machine.hasCurrentState);
	}

	public function testInitReplacesInstance()
	{
		var first = GameplayState.init(bus);
		var second = GameplayState.init(bus);
		Assert.notEquals(first, second);
		Assert.equals(second, GameplayState.get());
	}

	public function testAsyncRequestRoundTrip()
	{
		// "another system" publishes a request — no ref to the state singleton
		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));

		// not applied before flush
		Assert.isNull(state.current);

		// flush #1: request delivered → changeState executes synchronously
		bus.flush();
		Assert.equals(GameplayMode.fsSettings, state.current);
		Assert.equals(0, transitions.length); // confirm event still queued

		// flush #2: StateChangeEvent delivered — the "answer"
		bus.flush();
		Assert.equals(1, transitions.length);
		Assert.equals(GameplayMode.fsSettings, transitions[0].n);
		Assert.isNull(transitions[0].o);
	}

	public function testRawBusSubscriberSeesConfirm()
	{
		var got : Array<StateChangeEvent<GameplayMode>> = [];
		bus.subscribe(StateChangeEvent, function(e : StateChangeEvent<GameplayMode>) got.push(e));

		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));
		bus.flush();
		bus.flush();

		Assert.equals(1, got.length);
		Assert.equals(GameplayMode.fsSettings, got[0].newState);
	}

	public function testDirectChangeBehavesSynchronously()
	{
		Assert.isNull(state.current);

		// direct call: state set right away (machine API), event after flush
		state.changeState(GameplayMode.fsIngame);
		Assert.equals(GameplayMode.fsIngame, state.current);
		Assert.equals(0, transitions.length);

		bus.flush();
		Assert.equals(1, transitions.length);
		Assert.equals(GameplayMode.fsIngame, transitions[0].n);
	}

	public function testToggle()
	{
		state.changeState(GameplayMode.fsIngame);
		bus.flush();

		state.toggle();
		Assert.equals(GameplayMode.fsSettings, state.current);
		bus.flush();
		Assert.equals(2, transitions.length);
		Assert.equals(GameplayMode.fsSettings, transitions[1].n);
		Assert.equals(GameplayMode.fsIngame, transitions[1].o);

		state.toggle();
		Assert.equals(GameplayMode.fsIngame, state.current);
		bus.flush();
		Assert.equals(3, transitions.length);
	}

	public function testToggleRequestEvent()
	{
		// ESC-style: publisher needs NO knowledge of the current state —
		// just publishes the flip request, the singleton owns the decision
		bus.publish(new GameplayToggleRequest());

		// request delivered on flush #1, confirm event on flush #2
		bus.flush();
		Assert.equals(GameplayMode.fsSettings, state.current); // initial null → fsSettings
		bus.flush();

		// and toggle back through the bus again
		bus.publish(new GameplayToggleRequest());
		bus.flush();
		Assert.equals(GameplayMode.fsIngame, state.current);
		bus.flush();

		Assert.equals(2, transitions.length);
		Assert.equals(GameplayMode.fsSettings, transitions[0].n);
		Assert.equals(GameplayMode.fsIngame, transitions[1].n);
	}

	public function testDisposeUnsubscribesToggleHandler()
	{
		state.dispose();

		bus.publish(new GameplayToggleRequest());
		bus.flush();
		bus.flush();

		Assert.isNull(state.current); // nothing applied — handler removed
	}

	public function testDuplicateRequestIsNoOp()
	{
		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));
		bus.flush();
		bus.flush();
		Assert.equals(1, transitions.length);

		// same-state request → machine ignores, no event
		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));
		bus.flush();
		bus.flush();
		Assert.equals(1, transitions.length);
		Assert.equals(GameplayMode.fsSettings, state.current);
	}

	public function testDisposeUnsubscribesRequestHandler()
	{
		state.dispose();

		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));
		bus.flush();
		bus.flush();

		Assert.isNull(state.current); // nothing applied — handler removed
	}
}