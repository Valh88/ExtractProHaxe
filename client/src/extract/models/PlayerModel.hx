package extract.models;

/**
	Rigged player character (and, in the future, weapons/attachments).
	Loads the hero FBX via h3d.prim.ModelCache, plays the Running loop and
	applies the import corrections (rotation/scale) so it stands upright.
	Extends h3d.scene.Object so it can be added to any 3D scene and follow
	the physics hero body.
**/
class PlayerModel extends h3d.scene.Object
{
	var modelCache : h3d.prim.ModelCache;

	/** The rigged hero mesh, animated with the Running loop. */
	public var hero : h3d.scene.Object;

	public function new(?parent : h3d.scene.Object)
	{
		super(parent);

		// rigged character model (FBX converted to HMD at load), loaded via
		// h3d.prim.ModelCache — the standard Heaps way (loads textures automatically)
		modelCache = new h3d.prim.ModelCache();
		var heroRes = hxd.Res.load("models/hero/hero.fbx").toModel();
		hero = modelCache.loadModel(heroRes);
		hero.rotate(-Math.PI / 2, 0, 0);
		var runAnim = modelCache.loadAnimation(heroRes, "root|Running");
		if (runAnim != null)
			hero.playAnimation(runAnim);
		hero.scale(0.006); // ~1.7u hero from a ~2.37u model
		addChild(hero);
	}
}
