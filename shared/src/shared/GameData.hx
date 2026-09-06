package shared;

import cdb.Database;

/**
	Raw handle on the shared cdb database (`client/res/db/data.cdb`).
	ALL game data lives in the base — accessors are REQUIRED reads and
	throw a clear error when the db/sheet/field is missing (fail-fast at
	startup instead of silently-wrong physics).

	`req` for floats, `reqB` for bools, `line()` for whole rows, `db` for
	anything richer (multiple rows, ids).
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

	/** REQUIRED float: throws when db/sheet/field is missing or not numeric. */
	public function req(sheet : String, field : String) : Float
	{
		var l = line(sheet);
		if (l != null)
		{
			var v : Dynamic = Reflect.field(l, field);
			if (v != null && Std.isOfType(v, Float)) return v;
		}
		return fail(sheet, field, "numeric");
	}

	/** REQUIRED bool: throws when db/sheet/field is missing or not boolean. */
	public function reqB(sheet : String, field : String) : Bool
	{
		var l = line(sheet);
		if (l != null)
		{
			var v : Dynamic = Reflect.field(l, field);
			if (v != null && Std.isOfType(v, Bool)) return v;
		}
		return fail(sheet, field, "boolean");
	}

	static function fail(sheet : String, field : String, kind : String) : Dynamic
	{
		throw 'GameData: missing $kind field "$field" in sheet "$sheet" (data.cdb incomplete?)';
	}
}
