package extract.systems;

import hxd.Event;
import hxd.Window;

import shared.events.EventBus;
import shared.systems.System;

import extract.events.InputEvents.KeyEvent;
import extract.events.InputEvents.MouseMoveEvent;
import extract.events.InputEvents.MouseButtonEvent;

/**
	Central input tracker: the ONE owner of raw window input (desktop
	keyboard + mouse). Converts window events into edge-triggered bus events
	(`extract.events.InputEvents`) that gameplay systems subscribe to — nothing
	else adds `hxd.Window` event targets or polls `hxd.Key`.

	- Key down/up edges (OS key repeat filtered via an internal press map).
	- Mouse move with RELATIVE delta (safe for camera look) + absolute position.
	- Mouse button press/release, including release outside the window.

	Mobile later gets its own input system publishing the SAME bus events, so
	consumers (movement, look, shoot, UI shortcuts) stay unchanged.
**/
class InputSystem extends System
{
	// held reference: HL creates a NEW closure per `this.onWindowEvent` access,
	// and removeEventTarget matches via Reflect.compareMethods — reuse one
	final winHandler : Event -> Void;
	var win : Window;

	/** Currently-held keys (edge filter: no repeated EKeyDown publishes). */
	var keys : Map<Int, Bool> = new Map();
	var lastX : Float = 0;
	var lastY : Float = 0;
	/** First move has no baseline yet — publish position, zero delta. */
	var gotBaseline : Bool = false;

	public function new(bus : EventBus)
	{
		super(bus, null, null, "Input");
		winHandler = onWindowEvent;
		win = Window.getInstance();
		win.addEventTarget(winHandler);
	}

	function onWindowEvent(e : Event) : Void
	{
		switch (e.kind)
		{
			case EKeyDown:
				if (!keys.exists(e.keyCode))
				{
					keys.set(e.keyCode, true);
					bus.publish(new KeyEvent(e.keyCode, true));
				}
			case EKeyUp:
				if (keys.remove(e.keyCode))
					bus.publish(new KeyEvent(e.keyCode, false));
			case EMove:
				var dx = gotBaseline ? e.relX - lastX : 0;
				var dy = gotBaseline ? e.relY - lastY : 0;
				lastX = e.relX;
				lastY = e.relY;
				gotBaseline = true;
				bus.publish(new MouseMoveEvent(e.relX, e.relY, dx, dy));
			case EPush:
				bus.publish(new MouseButtonEvent(e.button, true, e.relX, e.relY));
			case ERelease | EReleaseOutside:
				bus.publish(new MouseButtonEvent(e.button, false, e.relX, e.relY));
			case _:
		}
	}

	override public function dispose() : Void
	{
		win.removeEventTarget(winHandler);
		keys = new Map();
		gotBaseline = false;
	}
}