package extract.utils;

import cdb.Database;
import shared.Config;

/**
	Starter client-side loader for the shared `res/db/data.cdb` (castle/cdb).
	Defaults come from Config; fields found in the `Gameplay` sheet override them.
	(Same file can later feed the headless server via sys.io.)
**/
class GameData
{
	public var floorHalf : Float;
	public var cubeSize : Float;
	public var cubeSpawnInterval : Float;
	public var gravityY : Float;

	public function new()
	{
		floorHalf = Config.FLOOR_HALF;
		cubeSize = Config.CUBE_SIZE;
		cubeSpawnInterval = Config.CUBE_SPAWN_INTERVAL;
		gravityY = Config.GRAVITY_Y;
	}

	public static function fromCdb(content : String) : GameData
	{
		var gd = new GameData();
		try
		{
			var db = new Database();
			db.load(content);
			var sheet = db.getSheet("Gameplay");
			if (sheet == null) return gd;
			var lines = sheet.getLines();
			if (lines.length == 0) return gd;
			var line = lines[0];
			for (f in ["floorHalf", "cubeSize", "cubeSpawnInterval", "gravityY"]) {
				var v : Dynamic = Reflect.field(line, f);
				if (v != null && Std.isOfType(v, Float))
					Reflect.setField(gd, f, v);
			}
		}
		catch (e : Dynamic)
		{
			// missing/unreadable file -> keep Config defaults
		}
		return gd;
	}
}