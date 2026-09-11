package shared.net;

/** Networking constants (RNL / UDP, HL only). */
class NetConfig
{
	/** Server host the client connects to. */
	public static inline var LOBBY_HOST : String = "127.0.0.1";

	/** Dedicated lobby port (fixed; game rooms use a pool). */
	public static inline var LOBBY_PORT : Int = 26260;

	/** Game room port pool start (inclusive). Each room gets its own port. */
	public static inline var GAME_PORT_START : Int = 1790;

	/** Game room port pool end (inclusive). */
	public static inline var GAME_PORT_END : Int = 1990;

	/** How many update/service rounds the server pumps before a client
		times out of the lobby (spike only, generous). */
	public static inline var CONNECT_MAX_ROUNDS : Int = 4000;

	/** Client-side connect timeout: if no lobby mirror arrives within this
		many seconds, the socket is dropped and onConnectTimeout fires. */
	public static inline var CONNECT_TIMEOUT_SECONDS : Float = 5.0;
}
