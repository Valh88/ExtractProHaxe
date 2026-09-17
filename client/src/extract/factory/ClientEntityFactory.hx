package extract.factory;

import h3d.scene.Mesh;
import h3d.scene.Object;
import h3d.prim.Primitive;

import phys.core.PhysBody;
import phys.render.PhysRenderer;

import shared.BaseEntityFactory;

/**
	Client-side entity factory: the shared recipes + a h3d mesh per body.
	`onBodyAdded` picks a mesh (`meshForBody`), parents it to the scene and
	binds it to the interpolating PhysRenderer; `onBodyRemoved` is NOT needed —
	the PhysRenderer already unbinds/removes the mesh when the body is removed
	(PhysCore.removeBody -> consumer.onBodyRemoved). The LOCAL hero's mesh is
	exposed (`localHeroVisual`) so the view can anchor the camera.

	meshForBody (heaps) must NOT live in the shared interface — it would drag
	h3d into the headless server build. That's the whole point of the split:
	recipes are shared (BaseEntityFactory), only the visuals are per side.
**/
class ClientEntityFactory extends BaseEntityFactory
{
	/** Scene node meshes are parented to (the game view). */
	final parent : h3d.scene.Object;

	/** Interpolating renderer every body is bound to (see bindRenderer). */
	var renderer : Null<PhysRenderer>;

	/** Visuals of the LOCAL hero, set when its body spawns — camera anchor. */
	public var localHeroVisual(default, null) : Null<extract.models.HeroVisual>;

	public function new(parent : h3d.scene.Object)
	{
		super();
		this.parent = parent;
	}

	/**
		Set once the PhysRenderer exists. The world must be created first
		(SimWorld.createWorld) because the renderer needs `sim.physCore`
		(for interpolation); level spawn (`sim.buildLevel`) MUST come after
		this so spawned meshes can bind immediately.
	**/
	public function bindRenderer(r : PhysRenderer) : Void
	{
		this.renderer = r;
	}

	override public function onBodyAdded(b : PhysBody) : Void
	{
		if (renderer == null) return;
		// LOCAL hero gets a HeroVisual (capsule + cameraAnchor + weapon);
		// remote heroes get a plain capsule from meshForBody.
		if (b.name == "hero" && world != null && world.hero == b)
		{
			var sizes = b.getShapeSizes();
			if (sizes == null) return;
			var visual = new extract.models.HeroVisual(parent, sizes.hx, sizes.hy);
			parent.addChild(visual);
			renderer.bind(b, visual.bodyMesh);
			localHeroVisual = visual;
			return;
		}
		var mesh = meshForBody(b);
		if (mesh == null) return;
		parent.addChild(mesh);
		renderer.bind(b, mesh);
	}

	override public function onBodyRemoved(b : PhysBody) : Void
	{
		// the PhysRenderer handles unbind/mesh removal (removeBody ->
		// consumer.onBodyRemoved); nothing extra to release yet.
	}

	/** Build a mesh for a spawned body. Extend this switch for new entities. */
	public function meshForBody(b : PhysBody) : Null<Mesh>
	{
		var sizes = b.getShapeSizes();
		if (sizes == null) return null;
		var prim : Primitive = switch (b.name)
		{
			case "floor":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			case "cube":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			case "hero":
				// capsule collider: hx = radius, hy = cylinder half-height; Oimo
				// capsule is Y-aligned, so build the heaps mesh on the Y axis
				var cap = new h3d.prim.Capsule(sizes.hx, sizes.hy * 2, 12, h3d.prim.Capsule.Axis.Y);
				cap.addNormals();
				cap;
			case "bullet":
				var s = new h3d.prim.Sphere(sizes.hx, 12, 8);
				s.addNormals();
				s;
			default:
				// static obstacle from the level prefab (pillars, ...): hide
				// draws the authored meshes on HL, so skip the sim box there;
				// targets without hide (web) fall back to this box.
			#if hide
				null;
			#else
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			#end
		}
		if (prim == null) return null;
		var poly = Std.downcast(prim, h3d.prim.Polygon);
		if (poly != null && poly.normals == null) poly.addNormals();
		if (poly != null) poly.addUVs();

		var m = h3d.mat.Material.create();
		var pbr = new h3d.shader.pbr.PropsValues();
		switch (b.name)
		{
			case "floor": // rough concrete
				pbr.metalnessValue = 0;
				pbr.roughnessValue = 0.9;
				m.color.set(0.6, 0.6, 0.6, 1);
			case "cube": // metal
				pbr.metalnessValue = 0.8;
				pbr.roughnessValue = 0.3;
				m.color.set(0.4, 0.6, 1, 1);
			case "hero": // warm orange hero capsule
				pbr.metalnessValue = 0.1;
				pbr.roughnessValue = 0.5;
				m.color.set(1, 0.55, 0.2, 1);
			case "bullet": // bright yellow projectile
				pbr.metalnessValue = 0.2;
				pbr.roughnessValue = 0.4;
				m.color.set(1, 0.95, 0.2, 1);
			default: // prefab obstacle (pillar, ...) — plain concrete
				pbr.metalnessValue = 0;
				pbr.roughnessValue = 0.85;
				m.color.set(0.55, 0.5, 0.45, 1);
		}
		m.mainPass.addShader(pbr);
		return new h3d.scene.Mesh(prim, m);
	}
}