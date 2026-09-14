package extract.utils;

import hxd.Event;
import hxd.Window;

/**
	Global input state singleton (desktop keyboard + mouse). ANY code can poll
	held keys/buttons or per-frame edges directly — no bus hop, no per-system
	event subscriptions, no repeated window-event targets (this class is the
	ONE `hxd.Window` listener):

	- `isDown(code)` / `isDownButton(b)` — held state, query any time.
	- `consumePressed(code)` / `consumePressedButton(b)` — edge: true once per
	  press per frame, auto-clears on first read.
	- `mouseDX` / `mouseDY` — relative mouse delta accumulated for the current
	  frame (safe for camera look under cursor-lock), `mouseX` / `mouseY` — abs.

	`update()` snapshots the frame's edges and resets the mouse delta; call it
	once per frame from `GamePlayView.update` BEFORE the consumer systems read.

	Mobile later gets its own `InputBackend` that feeds the same state, so
	consumers (movement, look, shoot, UI shortcuts) stay unchanged.
**/
class InputManager
{
	static var inst : InputManager;

	// held reference: HL creates a NEW closure per `this.onWindowEvent` access,
	// and removeEventTarget matches via Reflect.compareMethods — reuse ONE
	final winHandler : Event -> Void;
	final win : Window;

	// keyboard: held + edges accumulated since the last update()
	var keys : Map<Int, Bool> = new Map();
	var keyEdges : Map<Int, Bool> = new Map();
	// mouse buttons (0=left 1=right 2=middle): held + edges
	var mouseButtons : Map<Int, Bool> = new Map();
	var mouseEdges : Map<Int, Bool> = new Map();

	// snapshot of the current frame's edges (consumed via consumePressed*)
	var frameKeyEdges : Map<Int, Bool> = new Map();
	var frameMouseEdges : Map<Int, Bool> = new Map();

	/** Relative mouse movement for the current frame (world units). Snapshot —
		accumulated between `update()` calls, exposed here for frame consumers. */
	public var mouseDX(default, null) : Float = 0;
	public var mouseDY(default, null) : Float = 0;
	/** Absolute mouse position (window-space). */
	public var mouseX(default, null) : Float = 0;
	public var mouseY(default, null) : Float = 0;

	// live deltas filled by window events; copied to mouseDX/DY by update()
	var accDX : Float = 0;
	var accDY : Float = 0;
	var lastX : Float = 0;
	var lastY : Float = 0;
	/** First move has no baseline yet — publish position, zero delta. */
	var gotBaseline : Bool = false;

	function new()
	{
		win = Window.getInstance();
		winHandler = onWindowEvent;
		win.addEventTarget(winHandler);
	}

	/** The process-wide input singleton (created lazily on first get). */
	public static function get() : InputManager
	{
		if (inst == null) inst = new InputManager();
		return inst;
	}

	function onWindowEvent(e : Event) : Void
	{
		switch (e.kind)
		{
			case EKeyDown:
				if (!keys.exists(e.keyCode))
				{
					keys.set(e.keyCode, true);
					keyEdges.set(e.keyCode, true);
				}
			case EKeyUp:
				keys.remove(e.keyCode);
			case EMove:
				var dx = gotBaseline ? e.relX - lastX : 0;
				var dy = gotBaseline ? e.relY - lastY : 0;
				lastX = e.relX;
				lastY = e.relY;
				gotBaseline = true;
				accDX += dx;
				accDY += dy;
				mouseX = e.relX;
				mouseY = e.relY;
			case EPush:
				mouseButtons.set(e.button, true);
				mouseEdges.set(e.button, true);
			case ERelease:
				mouseButtons.remove(e.button);
			case EReleaseOutside:
				mouseButtons.remove(e.button);
			case _:
		}
	}

	/** True while `code` is held down. */
	public function isDown(code : Int) : Bool
		return keys.exists(code);

	/** True while mouse button `b` is held (0=left, 1=right, 2=middle). */
	public function isDownButton(b : Int) : Bool
		return mouseButtons.exists(b);

	/** Edge: true once per press, clears on first read (query each frame). */
	public function consumePressed(code : Int) : Bool
	{
		if (frameKeyEdges.exists(code))
		{
			frameKeyEdges.remove(code);
			return true;
		}
		return false;
	}

	/** Edge for a mouse button press — same semantics as `consumePressed`. */
	public function consumePressedButton(b : Int) : Bool
	{
		if (frameMouseEdges.exists(b))
		{
			frameMouseEdges.remove(b);
			return true;
		}
		return false;
	}

	/** Snapshot this frame's input: copy the deltas/edges accumulated since the
		last call into the read-only frame state and reset the accumulators.
		Called once per frame from `GamePlayView.update` (first thing). */
	public function update() : Void
	{
		mouseDX = accDX;
		mouseDY = accDY;
		accDX = 0;
		accDY = 0;
		frameKeyEdges = keyEdges;
		keyEdges = new Map();
		frameMouseEdges = mouseEdges;
		mouseEdges = new Map();
	}

	/** Remove the window listener. Lazy `get()` recreates on next use. */
	public function dispose() : Void
	{
		win.removeEventTarget(winHandler);
		if (inst == this) inst = null;
	}
}