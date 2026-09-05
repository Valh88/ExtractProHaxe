import cdb.Database;
import cdb.Data.Column;
import cdb.Data.ColumnType;
import sys.io.File;
import sys.FileSystem;

/**
	Generates the starter `data.cdb` (castle/cdb format) into client/res/db.
	Two sheets: `World` (floor/cubes/gravity) and `Hero` (capsule params).

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

		// --- World sheet ---
		var world = db.createSheet("World");
		if (world == null) {
			Sys.println("Sheet World already exists");
			Sys.exit(1);
		}
		addCols(world, [
			{ name : "id", type : TId },
			{ name : "floorHalf", type : TFloat },
			{ name : "cubeSize", type : TFloat },
			{ name : "cubeSpawnInterval", type : TFloat },
			{ name : "gravityY", type : TFloat },
		]);
		world.lines.push({
			id : "default",
			floorHalf : 10.0,
			cubeSize : 1.0,
			cubeSpawnInterval : 2.0,
			gravityY : -9.80665,
		});

		// --- Hero sheet ---
		var hero = db.createSheet("Hero");
		if (hero == null) {
			Sys.println("Sheet Hero already exists");
			Sys.exit(1);
		}
		addCols(hero, [
			{ name : "id", type : TId },
			{ name : "heroRadius", type : TFloat },
			{ name : "heroHalfHeight", type : TFloat },
		]);
		hero.lines.push({
			id : "default",
			heroRadius : 0.4,
			heroHalfHeight : 0.45, // total height = 2*(0.45 + 0.4) = 1.7
		});

		var dir = haxe.io.Path.directory(out);
		if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(out, db.save());
		Sys.println("Wrote " + out);

		// round-trip self-check
		var check = new Database();
		check.load(File.getContent(out));
		var w = check.getSheet("World").getLines()[0];
		var h = check.getSheet("Hero").getLines()[0];
		Sys.println("OK World: floorHalf=" + Reflect.field(w, "floorHalf")
			+ " cubeSize=" + Reflect.field(w, "cubeSize")
			+ " spawn=" + Reflect.field(w, "cubeSpawnInterval")
			+ " gravity=" + Reflect.field(w, "gravityY"));
		Sys.println("OK Hero: heroR=" + Reflect.field(h, "heroRadius")
			+ " heroHH=" + Reflect.field(h, "heroHalfHeight"));
	}

	static function addCols(sheet : cdb.Sheet, cols : Array<{ name : String, type : ColumnType }>) : Void
	{
		for (c in cols) {
			var err = sheet.addColumn({ name : c.name, type : c.type, typeStr : null });
			if (err != null) {
				Sys.println("addColumn " + c.name + " failed: " + err);
				Sys.exit(1);
			}
		}
	}
}
