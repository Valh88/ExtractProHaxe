package extract.utils;

/**
	Generic switcher for lazily created, cached sub-views — same pattern as
	`SceneManager<K>` but for domkit `SubView`s inside one parent view
	(e.g. lobby tabs).

	Generic over the tab key `K` (e.g. `LobbyTab`): construction is delegated
	to the `factory` (return null for not-implemented tabs — switching is then
	a no-op with a trace), `attach` receives every freshly created view (hook
	for container addChild + domkit style registration), `onSwitched` fires
	after every successful switch (hook for tab highlight).
**/
class SubViewSwitcher<K : EnumValue>
{
	/** Key of the currently visible sub-view. */
	public var current(default, null) : Null<K>;

	var factory : K -> Null<SubView<Dynamic>>;
	var attach : Null<SubView<Dynamic>> -> Void;
	var onSwitched : Null<K -> Void>;
	var views : Map<K, SubView<Dynamic>> = new Map();
	var currentView : Null<SubView<Dynamic>>;

	public function new(factory : K -> Null<SubView<Dynamic>>, ?attach : SubView<Dynamic> -> Void, ?onSwitched : K -> Void)
	{
		this.factory = factory;
		this.attach = attach;
		this.onSwitched = onSwitched;
	}

	/** Show the sub-view for `id`, creating it on first use. */
	public function switchTo(id : K) : Void
	{
		var v = views.get(id);
		if (v == null)
		{
			v = factory(id);
			if (v == null)
			{
				trace(id + " sub-view not implemented yet");
				return;
			}
			views.set(id, v);
			if (attach != null) attach(v);
		}
		if (currentView == v) return;

		if (currentView != null)
			currentView.design.visible = false;
		currentView = v;
		v.design.visible = true;
		current = id;
		if (onSwitched != null) onSwitched(id);
	}

	/** Pump IUpdate of the visible sub-view. */
	public function update(dt : Float) : Void
	{
		if (currentView != null)
			currentView.update(dt);
	}
}
