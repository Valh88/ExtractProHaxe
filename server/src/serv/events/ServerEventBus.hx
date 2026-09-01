package serv.events;

import shared.events.EventBus;

/** Server bus: local delivery + (future) broadcast to clients. */
class ServerEventBus extends EventBus
{
	override public function publish<T>( event : T ) : Void
	{
		super.publish(event); // queue for end-of-frame local delivery
		// TODO: broadcast `event` to clients
	}
}