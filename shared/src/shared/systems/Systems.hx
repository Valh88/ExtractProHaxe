package shared.systems;

import shared.IUpdate;

/**
	Ordered container of systems. Update order == insertion order, which keeps
	client and server simulations deterministic. Duplicate adds are ignored.
**/
class Systems implements IUpdate
{
	var list : Array<System> = [];
	var map : Map<String, System> = new Map();

	public function new() {}

	/** Register a system; a system with the same name is ignored. Returns the container for chaining. */
	public function add(s : System) : Systems
	{
		if (map.exists(s.name)) return this;
		map.set(s.name, s);
		list.push(s);
		return this;
	}

	public function get(name : String) : Null<System>
	{
		return map.get(name);
	}

	/** Type-safe lookup: var cam = systems.getSystem<PlayerCameraSystem>(); */
	public function getSystem<S : System>( type : Class<S> ) : Null<S>
	{
		var s = map.get(Type.getClassName(type));
		return cast s;
	}

	/** Remove by instance or by name. */
	public function remove(s : System) : Void
	{
		removeByName(s.name);
	}

	public function removeByName(name : String) : Void
	{
		var s = map.get(name);
		if (s == null) return;
		map.remove(name);
		list.remove(s);
	}

	public function clear() : Void
	{
		list.resize(0);
		map = new Map();
	}

	/** Advance systems in insertion order, skipping disabled ones. */
	public function update(dt : Float) : Void
	{
		for (s in list)
			if (s.enabled)
				s.update(dt);
	}

	/** Number of registered systems. */
	public var length(get, null) : Int;
	inline function get_length() : Int return list.length;
}
