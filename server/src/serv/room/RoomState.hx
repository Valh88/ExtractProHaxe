package serv.room;

/** Server-side lifecycle of a room. */
enum RoomState
{
	/** Lobby: waiting for players / matchmaking. */
	Waiting;
	/** Active gameplay. */
	InGame;
	/** Finished; being torn down. */
	Ended;
	/** Closed by the host; no longer ticking. */
	Closed;
}