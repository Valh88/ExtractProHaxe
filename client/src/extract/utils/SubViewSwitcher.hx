package extract.utils;

import extract.utils.animations.subswitchers.SubViewSwitchAnim;
import extract.utils.animations.subswitchers.SlideFadeSwitchAnim;

/**
	Generic switcher for lazily created, cached sub-views — same pattern as
	`SceneManager<K>` but for domkit `SubView`s inside one parent view
	(e.g. lobby tabs).

	Generic over the tab key `K` (e.g. `LobbyTab`): construction is delegated
	to the `factory` (return null for not-implemented tabs — switching is then
	a no-op with a trace), `attach` receives every freshly created view (hook
	for container addChild + domkit style registration), `onSwitched` fires
	after every successful switch (hook for tab highlight).

	Switching is instant by default (`switchTo`). `switchToAnimated` runs a
	`SubViewSwitchAnim` transition (by default the built-in `SlideFadeSwitchAnim`,
	pass another subclass to plug in a custom animation).
**/
class SubViewSwitcher<K : EnumValue>
{
	/** Key of the currently visible sub-view. */
	public var current(default, null) : Null<K>;

	/** Duration (seconds) of the built-in animated switch. */
	public var animDuration : Float = 0.35;

	/** Fallback slide distance when the parent container has no usable width. */
	public var animSlide : Float = 480;

	var factory : K -> Null<SubView<Dynamic>>;
	var attach : Null<SubView<Dynamic>> -> Void;
	var onSwitched : Null<K -> Void>;
	var views : Map<K, SubView<Dynamic>> = new Map();
	var currentView : Null<SubView<Dynamic>>;
	var switchAnim : Null<SubViewSwitchAnim>;

	public function new(factory : K -> Null<SubView<Dynamic>>, ?attach : SubView<Dynamic> -> Void, ?onSwitched : K -> Void)
	{
		this.factory = factory;
		this.attach = attach;
		this.onSwitched = onSwitched;
	}

	/** Show the sub-view for `id`, creating it on first use. */
	public function switchTo(id : K) : Void
	{
		cancelAnim();
		var v = resolveView(id);
		if (v == null) return;
		if (currentView == v) return;

		if (currentView != null)
			currentView.design.visible = false;
		currentView = v;
		v.design.visible = true;
		bringToFront(v);
		current = id;
		if (onSwitched != null) onSwitched(id);
	}

	/**
		Transition to the sub-view for `id`. Uses `anim` if given, otherwise the
		built-in `SlideFadeSwitchAnim` (outgoing slides away + fades, incoming
		slides in; direction follows the enum index of `id` vs the previous key).
		An in-flight transition is cancelled (snapped to rest) first.
	**/
	public function switchToAnimated(id : K, ?anim : SubViewSwitchAnim) : Void
	{
		cancelAnim();
		var v = resolveView(id);
		if (v == null) return;
		if (currentView == v) return;

		var oldKey = current;
		var prev = currentView;
		currentView = v;
		current = id;
		bringToFront(v);
		if (onSwitched != null) onSwitched(id);

		// nothing leaving — just show it
		if (prev == null)
		{
			v.design.x = 0;
			v.design.alpha = 1;
			v.design.visible = true;
			return;
		}

		var dir : Float = 1.0;
		if (oldKey != null && Type.enumIndex(id) < Type.enumIndex(oldKey)) dir = -1.0;

		var a = anim != null ? anim : new SlideFadeSwitchAnim(prev, v, dir, slideFor(v), animDuration);
		switchAnim = a;
		a.start();
	}

	/** Pump the active switch animation + IUpdate of the visible sub-view. */
	public function update(dt : Float) : Void
	{
		if (switchAnim != null)
		{
			var a = switchAnim;
			a.update(dt);
			if (a.isComplete) switchAnim = null;
		}
		if (currentView != null)
			currentView.update(dt);
	}

	// --- internal ---

	function resolveView(id : K) : Null<SubView<Dynamic>>
	{
		var v = views.get(id);
		if (v == null)
		{
			v = factory(id);
			if (v == null)
			{
				trace(id + " sub-view not implemented yet");
				return null;
			}
			views.set(id, v);
			if (attach != null) attach(v);
		}
		return v;
	}

	/** Stop the running transition and snap both views to rest. */
	function cancelAnim() : Void
	{
		if (switchAnim != null)
		{
			switchAnim.cancel();
			switchAnim = null;
		}
	}

	/** Slide distance for `v`: parent Flow width when available, else animSlide. */
	function slideFor(v : SubView<Dynamic>) : Float
	{
		var p = v.design.parent;
		if (p != null && Std.isOfType(p, h2d.Flow)) return (cast p : h2d.Flow).outerWidth;
		return animSlide;
	}

	/** Re-append `v` to its parent so it draws on top of the other sub-views. */
	function bringToFront(v : SubView<Dynamic>) : Void
	{
		if (v.design.parent != null) v.design.parent.addChild(v.design);
	}
}