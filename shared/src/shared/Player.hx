package shared;

/**
	Player identifier constants. In the single-player prototype the only
	player is the local one; when multiplayer lands, each connected client
	uses its own id and routes HeroMoveIntent / BulletFired through it.
**/
class Player
{
	/** The local player id (own input, own hero). */
	public static inline var LOCAL : String = "local";
}
