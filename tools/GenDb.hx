import cdb.Database;
import cdb.Data.Column;
import cdb.Data.ColumnType;
import sys.io.File;
import sys.FileSystem;

/**
	Generates the starter `data.cdb` (castle/cdb format) into client/res/db.

		haxe -lib castle -hl tools/gendb.hl -main GenDb -cp tools
		hl tools/gendb.hl [-out client/res/db/data.cdb]

	Idempotent: re-run after changing the schema to regenerate the file.
**/
class GenDb
{
	static function main()
	{
		var out = "client/res/db/data.cdb";
		var args = Sys.args();
		for (i in 0...args.length)
			if (args[i] == "-out" && i + 1 < args.length) out = args[i + 1];

		var db = new Database();
		var sheet = db.createSheet("Gameplay");
		if (sheet == null) {
			Sys.println("Sheet Gameplay already exists");
			Sys.exit(1);
		}

		var cols : Array<Column> = [
			{ name : "id", type : TId, typeStr : null },
			{ name : "floorHalf", type : TFloat, typeStr : null },
			{ name : "cubeSize", type : TFloat, typeStr : null },
			{ name : "cubeSpawnInterval", type : TFloat, typeStr : null },
			{ name : "gravityY", type : TFloat, typeStr : null },
			{ name : "heroRadius", type : TFloat, typeStr : null },
			{ name : "heroHalfHeight", type : TFloat, typeStr : null },
		];
		for (c in cols) {
			var err = sheet.addColumn(c);
			if (err != null) {
				Sys.println("addColumn " + c.name + " failed: " + err);
				Sys.exit(1);
			}
		}

		var line : Dynamic = {};
		Reflect.setField(line, "id", "default");
		Reflect.setField(line, "floorHalf", 10.0);
		Reflect.setField(line, "cubeSize", 1.0);
		Reflect.setField(line, "cubeSpawnInterval", 2.0);
		Reflect.setField(line, "gravityY", -9.80665);
		Reflect.setField(line, "heroRadius", 0.4);
		Reflect.setField(line, "heroHalfHeight", 0.45);
		sheet.lines.push(line);

		var dir = haxe.io.Path.directory(out);
		if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(out, db.save());
		Sys.println("Wrote " + out);

		var check = new Database();
		check.load(File.getContent(out));
		var s = check.getSheet("Gameplay");
		var l = s.getLines()[0];
		Sys.println("OK " + s.name + ": floorHalf=" + Reflect.field(l, "floorHalf")
			+ " cubeSize=" + Reflect.field(l, "cubeSize")
			+ " spawn=" + Reflect.field(l, "cubeSpawnInterval")
			+ " gravity=" + Reflect.field(l, "gravityY")
			+ " heroR=" + Reflect.field(l, "heroRadius")
			+ " heroHH=" + Reflect.field(l, "heroHalfHeight"));
	}
}