package shared;

import cdb.Database;

/**
	Raw handle on the shared cdb database (`client/res/db/data.cdb`).
	No mirrored fields: consumers query sheets directly — `f()` for a float
	from the first line of a sheet, `line()` for the whole row, or `db` for
	anything richer (multiple rows, other sheets, ids).

	`db` is null when no file could be parsed — every accessor then falls
	back to the caller-supplied default, so a missing/broken file never
	crashes startup.
**/
class GameData
{
	public var db(default, null) : Null<Database>;

	public function new(?db : Database)
	{
		this.db = db;
	}

	public static function fromCdb(content : String) : GameData
	{
		var db : Null<Database> = null;
		try
		{
			db = new Database();
			db.load(content);
		}
		catch (e : Dynamic)
		{
			db = null; // broken/foreign content -> behave like a missing file
		}
		return new GameData(db);
	}

	/** First line of `sheet`, or null when db/sheet/row is missing. */
	public function line(sheet : String) : Dynamic
	{
		if (db == null) return null;
		var s = db.getSheet(sheet);
		if (s == null) return null;
		var lines = s.getLines();
		return lines.length > 0 ? lines[0] : null;
	}

	/** Float `field` from the first line of `sheet`, or `def`. */
	public function f(sheet : String, field : String, def : Float) : Float
	{
		var l = line(sheet);
		if (l == null) return def;
		var v : Dynamic = Reflect.field(l, field);
		return v != null && Std.isOfType(v, Float) ? v : def;
	}
}
