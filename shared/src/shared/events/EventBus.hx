package shared.events;

/**
	Typed event bus shared by client and server.

	Usage:
		bus.subscribe(SearchStarted, function(e : SearchStarted) ...);
		bus.publish(new SearchStarted("Solo"));

	Events are queued on `publish()` and delivered on `flush()` (call once
	per frame, end of update). A handler publishing new events enqueues them
	for the NEXT frame, so dispatch is never reentrant.

	Client/server buses extend this and override `publish` to add transport
	(send to server / broadcast to clients) on top of local delivery.
**/
class EventBus
{
	// orig: the user handler (kept for unsubscribe matching), wrap: Any-based dispatcher
	var listeners : Map<String, Array<{ orig : Any, wrap : Any -> Void }>> = new Map();
	var queue : Array<{ type : String, event : Any }> = [];

	public function new() {}

	/** Subscribe to events of type T: subscribe(SearchStarted, e -> ...) — e is typed. */
	public function subscribe<T>( type : Class<T>, handler : T -> Void ) : Void
	{
		var key = Type.getClassName(type);
		var list = listeners.get(key);
		if (list == null)
		{
			list = [];
			listeners.set(key, list);
		}
		var h = handler; // pin T so the wrapper below keeps the concrete type
		list.push({ orig : h, wrap : function(v : Any)
		{
			var e : T = v; // Any -> T promotion via typed assignment
			h(e);
		} });
	}

	public function unsubscribe<T>( type : Class<T>, handler : T -> Void ) : Void
	{
		var list = listeners.get(Type.getClassName(type));
		if (list == null) return;
		for (i in 0...list.length)
			if (Reflect.compareMethods(list[i].orig, handler))
			{
				list.splice(i, 1);
				return;
			}
	}

	/** Queue event for delivery on flush(). Override to add transport. */
	public function publish<T>( event : T ) : Void
	{
		var cls = Type.getClass(event);
		if (cls == null) return;
		queue.push({ type : Type.getClassName(cls), event : event });
	}

	/** Deliver all queued events. Call once per frame (end of update). */
	public function flush() : Void
	{
		if (queue.length == 0) return;
		var q = queue;
		queue = []; // events published by handlers are delivered next frame
		for (item in q)
		{
			var list = listeners.get(item.type);
			if (list == null) continue;
			for (e in list)
				e.wrap(item.event);
		}
	}
}