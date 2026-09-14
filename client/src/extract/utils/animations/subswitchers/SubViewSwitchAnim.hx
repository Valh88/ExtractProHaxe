package extract.utils.animations.subswitchers;

import extract.utils.SubView;

/**
	Abstract base for sub-view switch transitions (used by `SubViewSwitcher`).

	A transition couples two sub-views: `from` (leaving the screen) and `to`
	(entering). Subclasses define `begin()` (set the start state and launch
	tweens) and `tick(dt)` (advance one frame), then call `finish()` when the
	tweens are done.

	Cancel semantics: `cancel()` snaps both views to rest WITHOUT calling
	`onComplete` — used when the user triggers another switch mid-transition.
	Future animations (fade, zoom, …) extend this class.
**/
abstract class SubViewSwitchAnim
{
	/** Sub-view leaving the screen. */
	public var from(default, null) : SubView<Dynamic>;

	/** Sub-view entering the screen. */
	public var to(default, null) : SubView<Dynamic>;

	/** True while the transition is running. */
	public var isRunning(default, null) : Bool = false;

	/** True after the transition completed (stays true until `start()`). */
	public var isComplete(default, null) : Bool = false;

	/** Called once when the transition completes (never on `cancel()`). */
	public var onComplete : Null<Void -> Void>;

	public function new(from : SubView<Dynamic>, to : SubView<Dynamic>)
	{
		this.from = from;
		this.to = to;
	}

	/** Start the transition (idempotent). */
	public function start() : Void
	{
		if (isRunning) return;
		isRunning = true;
		isComplete = false;
		begin();
	}

	/** Advance the transition by `dt` seconds (no-op unless running). */
	public function update(dt : Float) : Void
	{
		if (isRunning && !isComplete) tick(dt);
	}

	/** Snap both views to rest and stop. Fires no `onComplete`. */
	public function cancel() : Void
	{
		if (to != null)
		{
			to.design.x = 0;
			to.design.alpha = 1;
			to.design.visible = true;
		}
		if (from != null)
		{
			from.design.x = 0;
			from.design.alpha = 1;
			from.design.visible = false;
		}
		isRunning = false;
		isComplete = false;
		onComplete = null;
	}

	/** Restore `from` to rest + hide it, mark complete, fire `onComplete`. */
	public function finish() : Void
	{
		if (isComplete) return;
		if (from != null)
		{
			from.design.x = 0;
			from.design.alpha = 1;
			from.design.visible = false;
		}
		isRunning = false;
		isComplete = true;
		if (onComplete != null) onComplete();
	}

	// --- subclass hooks ---

	/** Set the start positions/visibility and launch the tweens. */
	function begin() : Void {}

	/** Advance one frame. Call `finish()` when the transition is done. */
	function tick(dt : Float) : Void {}
}