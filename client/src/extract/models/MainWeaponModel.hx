package extract.models;

/**
	Main weapon model (first-person view): loads the static gun FBX and the
	part animations (bolt/fire, magazine change/insert) from separate FBX
	resources, then plays them on the gun object. Part animations target the
	mesh objects BY NAME inside the gun hierarchy (Heaps animation bind does
	base.getObjectByName), so each anim FBX only needs to share the part names.
	Extends h3d.scene.Object so it can be added to any scene and parented to
	the camera / hand anchor. Subclasses override the *Resource() paths to
	swap in another weapon.
**/
class MainWeaponModel extends h3d.scene.Object
{
	var modelCache : h3d.prim.ModelCache;

	/** The static gun mesh, with the part meshes as named children. */
	public var weapon : h3d.scene.Object;

	var shutterFire : h3d.anim.Animation;
	var magazineChange : h3d.anim.Animation;
	var magazineInsert : h3d.anim.Animation;

	function modelResource() return "models/main_weapons/ak-74m/ak-74m.fbx";
	function shutterFireResource() return "models/main_weapons/ak-74m/ak-74m_shutter_fire.fbx";
	function magazineChangeResource() return "models/main_weapons/ak-74m/ak-74m_magazine_change.fbx";
	function magazineInsertResource() return "models/main_weapons/ak-74m/ak-74m_magazine_insert.fbx";

	public function new(?parent : h3d.scene.Object)
	{
		super(parent);

		// static gun (FBX converted to HMD at load) loaded via
		// h3d.prim.ModelCache — loads the actor/weapon textures automatically
		// (paths in the FBX resolve relative to the model folder, see
		// ModelCache.loadTexture fallback)
		modelCache = new h3d.prim.ModelCache();
		weapon = modelCache.loadModel(hxd.Res.load(modelResource()).toModel());
		addChild(weapon);
		// Blender's FBX exporter appends a numeric dedup suffix (_001, _002, …)
		// to duplicate mesh names, so the gun parts are named e.g.
		// "Magazine_lowT_001" while the part animation curves target the clean
		// names ("Magazine_lowT"). Heaps binds animations by object name
		// (base.getObjectByName), so strip the suffix or the animation objects
		// would be silently dropped and nothing would move.
		stripDedupSuffix(weapon);
		// part animation curves live in their own FBX files; each holds a
		// single animation stack (named after the Blender action). loadAnimation
		// without a name returns the first stack of the file.
		shutterFire = modelCache.loadAnimation(hxd.Res.load(shutterFireResource()).toModel());
		magazineChange = modelCache.loadAnimation(hxd.Res.load(magazineChangeResource()).toModel());
		magazineInsert = modelCache.loadAnimation(hxd.Res.load(magazineInsertResource()).toModel());
	}

	/** Bolt recoil (1–8 frames). */
	public function playShutterFire()
	{
		if (shutterFire != null) weapon.playAnimation(shutterFire);
	}

	/** Magazine detach + removal (1–90). */
	public function playMagazineChange()
	{
		if (magazineChange != null) weapon.playAnimation(magazineChange);
	}

	/** Magazine insertion back up (1–60). */
	public function playMagazineInsert()
	{
		if (magazineInsert != null) weapon.playAnimation(magazineInsert);
	}

	/** Stop the current part animation, leaving the weapon at its last pose. */
	public function stopWeapon()
	{
		weapon.stopAnimation();
	}

	/** Remove a trailing "_NNN" dedup suffix from every object name in the subtree. */
	static function stripDedupSuffix(o : h3d.scene.Object)
	{
		for (c in o.children)
		{
			var n = c.name;
			if (n != null)
			{
				var i = n.lastIndexOf("_");
				if (i > 0)
				{
					var suffix = n.substr(i + 1);
					var isDedup = true;
					if (suffix.length == 0) isDedup = false;
					for (j in 0...suffix.length)
					{
						var ch = suffix.charCodeAt(j);
						if (ch < '0'.code || ch > '9'.code)
						{
							isDedup = false;
							break;
						}
					}
					if (isDedup) c.name = n.substr(0, i);
				}
			}
			stripDedupSuffix(c);
		}
	}
}