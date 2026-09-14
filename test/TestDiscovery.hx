package test;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import haxe.io.Path;
#end

/**
	Compile-time discovery of `test/*Test.hx` cases.
	Drop a new `FooTest.hx` (a `utest.Test` subclass) into `test/` and the
	runner picks it up automatically — no runner edits required.
**/
class TestDiscovery
{
	/** Expands to `[new test.FooTest(), new test.BarTest(), ...]` (sorted). */
	public static macro function cases() : Expr
	{
		// the macro call site lives in test/ (Runner.hx) — resolve that dir
		var thisFile = Context.getPosInfos(Context.currentPos()).file;
		var dir = Path.directory(thisFile);

		var files = FileSystem.readDirectory(dir);
		files.sort(function(a, b) return (a < b) ? -1 : ((a > b) ? 1 : 0));

		var items : Array<Expr> = [];
		for (f in files)
		{
			if (!StringTools.endsWith(f, "Test.hx")) continue;
			var cls = f.substr(0, f.length - ".hx".length);
			var typePath : TypePath = { pack: ["test"], name: cls };
			items.push({ expr : ENew(typePath, []), pos : Context.currentPos() });
		}

		if (items.length == 0)
			Context.fatalError("no *Test.hx cases found in " + dir, Context.currentPos());

		return { expr : EArrayDecl(items), pos : Context.currentPos() };
	}
}