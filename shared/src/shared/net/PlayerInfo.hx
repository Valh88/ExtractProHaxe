#if sys
package shared.net;

import rnl.net.Serializable;

/** One row of the lobby roster (serializable payload, not replicated). */
class PlayerInfo extends Serializable
{
	@:s public var id : String = "";
	@:s public var name : String = "";
	@:s public var ready : Bool = false;

	public function new(?id : String, ?name : String, ?ready : Bool)
	{
		super();
		if (id != null) this.id = id;
		if (name != null) this.name = name;
		if (ready != null) this.ready = ready;
	}
}
#end
