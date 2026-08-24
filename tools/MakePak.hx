import hxd.fmt.pak.Writer;
import hxd.fmt.pak.Reader;
import sys.io.File;
import sys.FileSystem;

class MakePak
{
    static var bytes : Array<haxe.io.Bytes> = [];
    static var size : Float = 0;

    static function buildRec(path : String, dir : String) : hxd.fmt.pak.Data.File
    {
        var f = new hxd.fmt.pak.Data.File();
        f.name = path == "" ? "" : path.split("/").pop();
        var full = dir + (path == "" ? "" : "/" + path);
        if (FileSystem.isDirectory(full))
        {
            f.isDirectory = true;
            f.content = [];
            for (name in FileSystem.readDirectory(full))
            {
                if (name.charAt(0) == ".") continue;
                var sub = (path == "" ? name : path + "/" + name);
                var sf = buildRec(sub, dir);
                if (sf != null) f.content.push(sf);
            }
            if (f.content.length == 0 && path != "") return null;
        }
        else
        {
            var data = File.getBytes(full);
            f.dataPosition = size;
            f.dataSize = data.length;
            f.checksum = haxe.crypto.Adler32.make(data);
            bytes.push(data);
            size += data.length;
        }
        return f;
    }

    static function buildOne(resPath : String, outPrefix : String)
    {
        bytes = [];
        size = 0;
        var pak = new hxd.fmt.pak.Data();
        pak.version = 0;
        pak.root = buildRec("", resPath);
        var outFile = outPrefix + ".pak";
        var dir = haxe.io.Path.directory(outFile);
        if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
        var f = File.write(outFile);
        new Writer(f, 0).write(pak, null, bytes);
        f.close();
        Sys.println("Wrote " + outFile + " (" + Std.int(size) + " bytes of content)");
    }

    static function fmtSize(b : Float) : String {
        if (b >= 1024*1024*1024) return Std.string(Math.round(b*10/(1024*1024*1024))/10)+"Gb";
        if (b >= 1024*1024) return Std.string(Math.round(b*10/(1024*1024))/10)+"Mb";
        if (b >= 1024) return Std.string(Math.round(b*10/1024)/10)+"Kb";
        return Std.string(b)+"b";
    }

    static function calcRec(f : hxd.fmt.pak.Data.File) : Float {
        if (!f.isDirectory) return f.dataSize;
        var total = 0.;
        for (c in f.content) total += calcRec(c);
        return total;
    }

    static function printRec(f : hxd.fmt.pak.Data.File, indent : String) {
        var size = calcRec(f);
        var label = f.name == "" ? "<root>" : f.name;
        Sys.println(indent + (f.isDirectory ? "> " : "  ") + label + "  " + fmtSize(size));
        if (f.isDirectory)
            for (c in f.content) printRec(c, indent + "  ");
    }

    static function infoPak(path : String) {
        if (!FileSystem.exists(path)) { Sys.println("No such pak: " + path); return; }
        var fs = File.read(path);
        var pak = new hxd.fmt.pak.Reader(fs).readHeader();
        Sys.println("PAK " + path + "  (version " + pak.version + ", header " + pak.headerSize + "b, data " + pak.dataSize + "b)");
        printRec(pak.root, "");
        fs.close();
    }

    static function main()
    {
        var args = Sys.args();
        var resPath : String = null;
        var outPrefix : String = null;
        var infoPath : String = null;
        var used = false;
        function flush() {
            if (resPath != null && outPrefix != null) {
                buildOne(resPath, outPrefix);
                resPath = null;
                outPrefix = null;
                used = true;
            }
        }
        var i = 0;
        while (i < args.length) {
            var a = args[i];
            if (a == "-info" && i + 1 < args.length) { infoPath = args[i + 1]; i += 2; }
            else if (a == "-res" && i + 1 < args.length) { resPath = args[i + 1]; i += 2; }
            else if (a == "-out" && i + 1 < args.length) { outPrefix = args[i + 1]; i += 2; }
            else { i++; }
            flush();
        }
        if (infoPath != null) { infoPak(infoPath); return; }
        if (!used) {
            // без аргументов — совместимость: client/res -> bin/client/res.pak + bin/web/res.pak
            Sys.println("No -res/-out given, building default client/res");
            buildOne("client/res", "bin/client/res");
            buildOne("client/res", "bin/web/res");
        }
    }
}
