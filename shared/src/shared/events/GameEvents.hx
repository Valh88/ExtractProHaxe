package shared.events;

/** Fired when a player pressed SEARCH in the lobby. */
class SearchStarted
{
	public var mode : String;

	public function new(mode : String)
	{
		this.mode = mode;
	}
}