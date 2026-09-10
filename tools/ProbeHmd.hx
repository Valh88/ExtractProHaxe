class ProbeHmd
{
	static function main()
	{
		hxd.Res.initLocal();
		var path = "models/899REZENOKVJPE5OJQCQ3Z5LA_Running/899REZENOKVJPE5OJQCQ3Z5LA.fbx";
		var any = hxd.Res.load(path);
		trace("any class=" + Type.getClassName(Type.getClass(any)));
		trace("entry class=" + Type.getClassName(Type.getClass(any.entry)));
		var raw = any.entry.getBytes();
		trace("getBytes len=" + raw.length + " head20=" + (raw.length > 20 ? raw.getString(0, 20) : "short"));
		var model = any.toModel();
		trace("toModel class=" + Type.getClassName(Type.getClass(model)));
		var lib = model.toHmd();
		var d = lib.header;
		var skins = 0;
		for (m in d.models)
			if (m.skin != null) skins++;
		trace("HMD: models=" + d.models.length + " skinned=" + skins + " materials=" + d.materials.length + " animations=" + d.animations.length + " shapes=" + d.shapes.length);
		for (m in d.models)
			trace("model: " + m.name + " skin=" + (m.skin != null ? "yes" : "no"));
		for (mt in d.materials)
			trace("mat: " + mt.name + " diffuse=" + mt.diffuseTexture + " blend=" + mt.blendMode);
		// per-skinned-model material split
		for (m in d.models)
		{
			if (m.skin == null) continue;
			trace("skin " + m.name + " materials=" + (m.materials == null ? "null" : Std.string([for (mi in m.materials) d.materials[mi].name])));
		}
		trace("PROBE OK");
	}
}