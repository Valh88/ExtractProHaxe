package shared;

class Config
{
	/** Fixed physics tick rate (Hz). Rendering interpolates in-between. */
	public static inline var PHYSICS_HZ : Float = 30;

	/** World gravity along Y (physics is Y-up). */
	public static inline var GRAVITY_Y : Float = -9.80665;

	/** Floor half-extents (X and Z). */
	public static inline var FLOOR_HALF : Float = 10;

	/** Cube edge length spawned by the demo rule. */
	public static inline var CUBE_SIZE : Float = 1;

	/** Seconds between auto-spawned cubes. */
	public static inline var CUBE_SPAWN_INTERVAL : Float = 2;

	/** How long the headless server simulates before exiting. */
	public static inline var SERVER_RUN_SECONDS : Float = 500;

	/** Default number of worker threads in the server room pool (HL has no cpuCount). */
	public static inline var POOL_WORKERS : Int = 2;
}
