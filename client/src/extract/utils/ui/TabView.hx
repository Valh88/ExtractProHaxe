package extract.utils.ui;

import h2d.Flow;
import h2d.domkit.Style;
import extract.utils.SubView;
import extract.utils.SubViewSwitcher;

/**
	Generic, reusable tab content area. Manages a `SubViewSwitcher<K>`,
	clipping (`overflow = Hidden`), style registration and per-frame update
	for a dedicated content container Flow.

	Generic over the tab key `K` (e.g. a menu/settings enum). The `factory`
	creates the sub-view for a given key on first use. Pass this to any
	host object that owns a content Flow (settings panel, lobby menu, etc.)
	and the host calls `switchTo`/`switchToAnimated` + `update`.

	Typical setup in the host constructor:
		var tv = new TabView<MyTab>(contentFlow, style, createMySubView);
		tv.switchTo(Audio); // default
		// wire a tab bar click:
		onTab = tv.switchToAnimated;
		// in update:
		override update(dt) { tv.update(dt); }
**/
class TabView<K : EnumValue>
{
	/** Currently visible tab key (mirrors the underlying switcher). */
	public var current(default, null) : Null<K>;

	/** Switch animation duration in seconds (see SubViewSwitcher). */
	public var animDuration(get, set) : Float;

	var container : Flow;
	var style : Style;
	var switcher : SubViewSwitcher<K>;

	public function new(container : Flow, style : Style, factory : K -> Null<SubView<Dynamic>>)
	{
		this.container = container;
		this.style = style;
		container.overflow = h2d.Flow.FlowOverflow.Hidden;
		switcher = new SubViewSwitcher<K>(factory, attach, null);
	}

	/** Instant switch. */
	public function switchTo(id : K) : Void
	{
		switcher.switchTo(id);
		current = switcher.current;
	}

	/** Animated switch (slide + fade via `SlideFadeSwitchAnim`). */
	public function switchToAnimated(id : K) : Void
	{
		switcher.switchToAnimated(id);
		current = switcher.current;
	}

	/** Convenience: animated by default, instant when `animated = false`. */
	public function select(id : K, ?animated : Bool = true) : Void
	{
		if (animated) switchToAnimated(id) else switchTo(id);
	}

	/** Call every frame from the owning view. */
	public function update(dt : Float) : Void
	{
		switcher.update(dt);
		current = switcher.current;
	}

	// --- internal ---

	function attach(sub : SubView<Dynamic>) : Void
	{
		container.addChild(sub.design);
		container.getProperties(sub.design).isAbsolute = true;
		style.addObject(sub.design);
	}

	inline function get_animDuration() : Float
		return switcher.animDuration;

	inline function set_animDuration(v : Float) : Float
		return switcher.animDuration = v;
}