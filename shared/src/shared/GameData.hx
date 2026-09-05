package shared;

import cdb.Database;

/**
	Data-driven game numbers loaded from the shared `res/db/data.cdb`
	(castle/cdb). Defaults come from `Config`; values found in the
	`Gameplay` sheet override them. No heaps dependency — the same parser
	feeds the client (`hxd.Res`) and the headless server (`sys.io.File`).
**/
class GameData
{
	/** Raw parsed database (null when built from defaults without cdb). */
	public var db(default, null) : Database;

	public var floorHalf : Float;
	public var cubeSize : Float;
	public var cubeSpawnInterval : Float;
	public var gravityY : Float;

	/** Hero capsule radius (total height = 2*(heroHalfHeight + heroRadius)). */
	public var heroRadius : Float;

	/** Hero capsule cylinder half-height. */
	public var heroHalfHeight : Float;

	public function new()
	{
		floorHalf = Config.FLOOR_HALF;
		cubeSize = Config.CUBE_SIZE;
		cubeSpawnInterval = Config.CUBE_SPAWN_INTERVAL;
		gravityY = Config.GRAVITY_Y;
		heroRadius = 0.4;
		heroHalfHeight = 0.45; // total height = 2*(0.45 + 0.4) = 1.7
	}

	public static function fromCdb(content : String) : GameData
	{
		var gd = new GameData();
		try
		{
			var db = new Database();
			db.load(content);
			gd.db = db;
			var world = db.getSheet("World");
			if (world != null && world.getLines().length > 0) {
				var line = world.getLines()[0];
				for (f in ["floorHalf", "cubeSize", "cubeSpawnInterval", "gravityY"]) {
					var v : Dynamic = Reflect.field(line, f);
					if (v != null && Std.isOfType(v, Float))
						Reflect.setField(gd, f, v);
				}
			}
			var hero = db.getSheet("Hero");
			if (hero != null && hero.getLines().length > 0) {
				var line = hero.getLines()[0];
				for (f in ["heroRadius", "heroHalfHeight"]) {
					var v : Dynamic = Reflect.field(line, f);
					if (v != null && Std.isOfType(v, Float))
						Reflect.setField(gd, f, v);
				}
			}
		}
		catch (e : Dynamic)
		{
			// missing/unreadable file -> keep Config defaults
		}
		return gd;
	}
}
