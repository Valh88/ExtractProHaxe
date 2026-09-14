package test;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayStateRequest;
import extract.fsm.GameplayToggleRequest;
import extract.systems.GameplayFsm;
import shared.events.EventBus;
import shared.utils.fsm.StateChangeEvent;
import utest.Assert;

/**
	Integration test of the client gameplay FSM (`extract.systems.GameplayFsm`)
	against a real `EventBus`: the full async request→flush→confirm round trip,
	toggle, duplicate-request no-op and dispose cleanup.
**/
class GameplayFsmTest extends utest.Test
{
	var bus : EventBus;
	var fsm : GameplayFsm;
	var transitions : Array<{n : GameplayMode, o : GameplayMode}> = [];

	function setup()
	{
		bus = new EventBus();
		fsm = new GameplayFsm(bus, null);
		transitions.resize(0);
		fsm.onState(function(n, o) transitions.push({n: n, o: o}));
	}

	function teardown()
	{
		fsm.dispose();
	}

	public function testStartsWithoutState()
	{
		Assert.isNull(fsm.current);
		Assert.isNull(fsm.machine.currentState);
		Assert.isFalse(fsm.machine.hasCurrentState);
	}

	public function testAsyncRequestRoundTrip()
	{
		// "another system" publishes a request — no ref to the fsm
		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));

		// not applied before flush
		Assert.isNull(fsm.current);

		// flush #1: request delivered → changeState executes synchronously
		bus.flush();
		Assert.equals(GameplayMode.fsSettings, fsm.current);
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
		Assert.isNull(fsm.current);

		// direct call: state set right away (machine API), event after flush
		fsm.changeState(GameplayMode.fsIngame);
		Assert.equals(GameplayMode.fsIngame, fsm.current);
		Assert.equals(0, transitions.length);

		bus.flush();
		Assert.equals(1, transitions.length);
		Assert.equals(GameplayMode.fsIngame, transitions[0].n);
	}

	public function testToggle()
	{
		fsm.changeState(GameplayMode.fsIngame);
		bus.flush();

		fsm.toggle();
		Assert.equals(GameplayMode.fsSettings, fsm.current);
		bus.flush();
		Assert.equals(2, transitions.length);
		Assert.equals(GameplayMode.fsSettings, transitions[1].n);
		Assert.equals(GameplayMode.fsIngame, transitions[1].o);

		fsm.toggle();
		Assert.equals(GameplayMode.fsIngame, fsm.current);
		bus.flush();
		Assert.equals(3, transitions.length);
	}

	public function testToggleRequestEvent()
	{
		// ESC-style: publisher needs NO knowledge of the current state —
		// just publishes the flip request, the FSM owns the decision
		bus.publish(new GameplayToggleRequest());

		// request delivered on flush #1, confirm event on flush #2
		bus.flush();
		Assert.equals(GameplayMode.fsSettings, fsm.current); // initial null → fsSettings
		bus.flush();

		// and toggle back through the bus again
		bus.publish(new GameplayToggleRequest());
		bus.flush();
		Assert.equals(GameplayMode.fsIngame, fsm.current);
		bus.flush();

		Assert.equals(2, transitions.length);
		Assert.equals(GameplayMode.fsSettings, transitions[0].n);
		Assert.equals(GameplayMode.fsIngame, transitions[1].n);
	}

	public function testDisposeUnsubscribesToggleHandler()
	{
		fsm.dispose();

		bus.publish(new GameplayToggleRequest());
		bus.flush();
		bus.flush();

		Assert.isNull(fsm.current); // nothing applied — handler removed
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
		Assert.equals(GameplayMode.fsSettings, fsm.current);
	}

	public function testDisposeUnsubscribesRequestHandler()
	{
		fsm.dispose();

		bus.publish(new GameplayStateRequest(GameplayMode.fsSettings));
		bus.flush();
		bus.flush();

		Assert.isNull(fsm.current); // nothing applied — handler removed
	}
}