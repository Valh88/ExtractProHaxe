package extract.events;

/**
	Centralized input payloads published by `extract.systems.InputSystem` on the
	view bus. Consumers subscribe instead of polling `hxd.Key`/window events, so
	the input SOURCE is swappable: desktop (keyboard+mouse) today, a touch system
	on mobile — same bus events, consumers unchanged.

	All events are edge-triggered: `KeyEvent` fires once per physical transition
	(OS key repeat is filtered by the InputSystem); `MouseButtonEvent` per
	press/release. `MouseMoveEvent` carries the RELATIVE delta since the last
	move (safe for camera look without a position baseline).
**/
class KeyEvent
{
	/** Key code (hxd.Key constant, e.g. hxd.Key.ESCAPE). */
	public var keyCode(default, null) : Int;
	/** true = freshly pressed, false = released. */
	public var pressed(default, null) : Bool;

	public function new(keyCode : Int, pressed : Bool)
	{
		this.keyCode = keyCode;
		this.pressed = pressed;
	}
}

class MouseMoveEvent
{
	/** Window-relative cursor position. */
	public var x(default, null) : Float;
	public var y(default, null) : Float;
	/** Delta since the last move (window-space pixels). */
	public var dx(default, null) : Float;
	public var dy(default, null) : Float;

	public function new(x : Float, y : Float, dx : Float, dy : Float)
	{
		this.x = x;
		this.y = y;
		this.dx = dx;
		this.dy = dy;
	}
}

class MouseButtonEvent
{
	/** hxd button id: 0 = left, 1 = right, 2 = middle. */
	public var button(default, null) : Int;
	/** true = freshly pressed, false = released. */
	public var pressed(default, null) : Bool;
	public var x(default, null) : Float;
	public var y(default, null) : Float;

	public function new(button : Int, pressed : Bool, x : Float, y : Float)
	{
		this.button = button;
		this.pressed = pressed;
		this.x = x;
		this.y = y;
	}
}