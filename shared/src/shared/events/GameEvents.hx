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

/**
	Client -> sim movement intent: world-space move direction (normalized
	horizontal), eased magnitude 0..1 (smooth accel/decel), the desired
	body yaw (camera yaw) and a one-shot jump request. Published only when
	state changes; the sim (HeroSystem) applies it each tick.
**/
class HeroMoveIntent
{
	public var dirX : Float;
	public var dirZ : Float;
	public var yaw : Float;
	public var mag : Float;
	/** One-shot jump request (consumed by the sim on delivery). */
	public var jump : Bool;

	public function new(dirX : Float, dirZ : Float, yaw : Float, mag : Float, jump : Bool)
	{
		this.dirX = dirX;
		this.dirZ = dirZ;
		this.yaw = yaw;
		this.mag = mag;
		this.jump = jump;
	}
}