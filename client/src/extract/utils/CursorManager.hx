package extract.utils;

import hxd.impl.MouseMode;

/**
	Singleton cursor state manager. Wraps Heaps' `Window.mouseMode` to
	provide a simple show/hide API for different game states.

	Usage:
	```
	CursorManager.get().hide();   // gameplay
	CursorManager.get().show();   // UI / menus
	```

	Future: pointer lock, cursor images, EventBus-driven state transitions.
**/
class CursorManager
{
	static var _inst : CursorManager;

	var window : hxd.Window;

	public static function get() : CursorManager
	{
		if (_inst == null) _inst = new CursorManager();
		return _inst;
	}

	function new()
	{
		window = hxd.Window.getInstance();
	}

	/** Hide the cursor (gameplay, FPS). EMove still fires — input code unchanged. */
	public function hide() : Void
	{
		window.mouseMode = AbsoluteUnbound(true);
	}

	/** Show the cursor (UI, menus, inventory). */
	public function show() : Void
	{
		window.mouseMode = Absolute;
	}

	/** True when the cursor is hidden (non-Absolute mode). */
	public var isHidden(get, never) : Bool;

	function get_isHidden() : Bool
	{
		return switch (window.mouseMode)
		{
			case Absolute: false;
			default: true;
		}
	}
}
