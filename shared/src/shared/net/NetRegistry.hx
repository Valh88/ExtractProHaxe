package shared.net;

import rnl.net.Registry;

/**
	Registers every networked class that may cross the wire BY CLID (the
	value-carrying `Serializable` payloads used as `@:rpc` args / `@:s` fields).

	`rnl.net.Registry` is filled lazily on `getCLID` — a peer that only RECEIVES
	a value (e.g. `PlayerInfo` inside `rosterChanged`) never calls `getCLID` for
	it, so `Registry.getClassName(clid)` would return null and deserialization
	crashes. Registering eagerly on both ends fixes that.

	Class objects referenced by name in ADD/FULLSYNC (e.g. `LobbyNet`) resolve
	via `Type.resolveClass` and do NOT need CLID registration, but registering
	them is harmless.
**/
class NetRegistry
{
	static var done : Bool = false;

	public static function init() : Void
	{
		if (done) return;
		done = true;
		Registry.getCLID(Type.getClassName(PlayerInfo));
		Registry.getCLID(Type.getClassName(LobbyNet));
	}
}
