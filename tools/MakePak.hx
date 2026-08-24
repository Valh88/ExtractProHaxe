import hxd.fmt.pak.Writer;
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

    static function main()
    {
        var resPath = "client/res";
        var outPrefix = "bin/web/res";
        bytes = [];
        size = 0;
        var pak = new hxd.fmt.pak.Data();
        pak.version = 0;
        pak.root = buildRec("", resPath);
        var outFile = outPrefix + ".pak";
        var f = File.write(outFile);
        new Writer(f, 0).write(pak, null, bytes);
        f.close();
        Sys.println("Wrote " + outFile + " (" + Std.int(size) + " bytes of content)");
    }
}
