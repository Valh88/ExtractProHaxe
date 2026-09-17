package;

import hxd.fmt.fbx.Parser;
import hxd.fmt.fbx.HMDOut;
import hxd.fmt.hmd.Data;

class ProbeFbx
{
	static function main()
	{
		var args = Sys.args();
		for (path in args)
		{
			trace("========================================");
			trace("FILE " + path);
			try {
				var bytes = sys.io.File.getBytes(path);
				var fbx = Parser.parse(bytes);
				var out = new HMDOut(path);
				out.load(fbx);
				var names = out.getAnimationNames();
				trace("getAnimationNames: " + names);
				var hmd = out.toHMD(null, true);
				trace("header.animations.length = " + hmd.animations.length);
				for (a in hmd.animations)
				{
					trace("  anim name='" + a.name + "' frames=" + a.frames + " sampling=" + a.sampling);
					var objs = new Array<String>();
					for (o in a.objects)
						objs.push(o.name);
					trace("   objects: " + objs.toString());
				}
				var models = new Array<String>();
				for (m in hmd.models)
					models.push(m.name);
				trace("header.models (" + hmd.models.length + "): " + models.toString());
			}
			catch (e:Dynamic)
			{
				trace("ERROR: " + Std.string(e));
			}
		}
	}
}