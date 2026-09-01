package extract.events;

import shared.events.EventBus;

/** Client bus: local delivery + (future) send to server. */
class ClientEventBus extends EventBus
{
	override public function publish<T>( event : T ) : Void
	{
		super.publish(event); // queue for end-of-frame local delivery
		// TODO: serialize `event` and send to server
	}
}