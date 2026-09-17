package extract.models;

import h3d.scene.Mesh;
import h3d.scene.Object;

/**
	Groups all visuals belonging to the LOCAL hero:
	- bodyMesh — capsule placeholder (will be replaced with a rigged FBX later)
	- cameraAnchor — invisible Object synced to the camera each frame so the
	  weapon follows the eye rotation without parenting to the camera (which
	  is NOT a scene node in Heaps)
	- mainWeapon — first-person weapon model, child of cameraAnchor

	PhysRenderer.bind requires a Mesh, so bodyMesh is exposed separately.
**/
class HeroVisual extends Object
{
	/** Capsule mesh that the PhysRenderer binds to the hero PhysBody. */
	public var bodyMesh : Mesh;

	/** Invisible anchor synced to cam.pos / yaw / pitch every frame. */
	public var cameraAnchor : Object;

	/** First-person weapon (child of cameraAnchor). */
	public var mainWeapon : MainWeaponModel;

	public function new(parent : Object, radius : Float, halfHeight : Float)
	{
		super(parent);

		// --- capsule placeholder ---
		var cap = new h3d.prim.Capsule(radius, halfHeight * 2, 12, h3d.prim.Capsule.Axis.Y);
		cap.addNormals();
		var m = h3d.mat.Material.create();
		var pbr = new h3d.shader.pbr.PropsValues();
		pbr.metalnessValue = 0.1;
		pbr.roughnessValue = 0.5;
		m.color.set(1, 0.55, 0.2, 1);
		m.mainPass.addShader(pbr);
		bodyMesh = new Mesh(cap, m);
		addChild(bodyMesh);

		// --- camera anchor (weapon follows eye) ---
		cameraAnchor = new Object(this);
		mainWeapon = new MainWeaponModel(cameraAnchor);
		mainWeapon.x = 0.2;
		mainWeapon.y = -0.15;
		mainWeapon.z = -0.4;
		// FBX model faces +X; rotate -90° around Y so it points forward (-Z)
		mainWeapon.setRotation(-Math.PI / 2, -Math.PI / 2, 0);
	}
}
