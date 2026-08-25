import sys.io.File;
import sys.FileSystem;
import StringTools;

/**
 * Re-applies the one-line cast patch to heaps-git's `hxd/fmt/hmd/Library.hx`
 * (see AGENTS.md, "Building res.pak"). The patch lives outside this repo (in the
 * global heaps-git checkout) and is wiped on any heaps update, so this restores it.
 *
 * Usage:
 *   haxe -lib heaps -hl tools/applypatch.hl -main ApplyHeapsPatch -cp tools
 *   hl tools/applypatch.hl [<path-to-Library.hx>]
 *
 * Exit codes: 0 = patched or already patched, 1 = file not found, 2 = target line missing.
 */
class ApplyHeapsPatch {
	static function main() {
		var target = "C:/Users/simpl/scoop/apps/haxe/current/lib/heaps/git/hxd/fmt/hmd/Library.hx";
		var args = Sys.args();
		if (args.length > 0) target = args[0];

		var needle = "buf.vertexes = haxe.ds.Vector.fromData(vertexes.getNative());";
		var repl   = "buf.vertexes = haxe.ds.Vector.fromData(cast vertexes.getNative());";

		if (!FileSystem.exists(target)) {
			Sys.println("NOT FOUND: " + target);
			Sys.exit(1);
		}
		var content = File.getContent(target);
		if (content.indexOf(repl) >= 0) {
			Sys.println("ALREADY PATCHED: " + target);
			return;
		}
		if (content.indexOf(needle) < 0) {
			Sys.println("PATCH TARGET NOT FOUND (heaps may already differ or be fixed): " + target);
			Sys.exit(2);
		}
		File.saveContent(target, StringTools.replace(content, needle, repl));
		Sys.println("PATCH APPLIED: " + target);
	}
}
