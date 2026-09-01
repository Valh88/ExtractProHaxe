package extract.views;

import h3d.Vector;
import h3d.scene.Scene as Scene3D;
import h2d.Scene as Scene2D;
import h2d.domkit.Style;

import phys.core.PhysBody;
import phys.core.PhysCore;
import phys.render.PhysRenderer;

import shared.SimWorld;
import shared.IUpdate;
import extract.design.HudDesign;

class GamePlayView extends Scene3D implements IUpdate
{
	var style : Style;
	var s2d : Scene2D;
	var hud : HudDesign;

	var sim : SimWorld;
	var physRenderer : PhysRenderer;

	public function new(s2d : Scene2D, style : Style)
	{
		super();
		this.s2d = s2d;
		this.style = style;

		h3d.Engine.getCurrent().backgroundColor = 0x0D0D0D;
		camera.up.set(0, 1, 0);
		camera.pos.set(8, 8, 8);
		camera.target.set(0, 1, 0);

		var light = new h3d.scene.pbr.DirLight(new Vector(-0.5, -0.4, -1), this);
		light.power = 2;
		light.isMainLight = true;
		light.shadows.mode = h3d.pass.Shadows.RenderMode.Dynamic;
		light.shadows.size = 2048;
		light.shadows.power = 150;
		light.shadows.bias *= 0.3;

		// project-wide screen-space AO (PBR renderer only)
		this.renderer.effects.push(new extract.gfx.ScalableAO());

		// shared simulation вЂ” same class the server runs
		sim = new SimWorld();

		// CLIENT consumer: maps each PhysBody to a mesh and interpolates it
		physRenderer = new PhysRenderer();
		sim.phys.addConsumer(physRenderer);

		// when the shared logic spawns a body, the client decides how to draw it
		sim.onSpawn = b ->
		{
			var mesh = meshForBody(b);
			if (mesh != null)
			{
				this.addChild(mesh);
				physRenderer.bind(b, mesh);
			}
		};
		// draw the initial scene too (created before onSpawn was set)
		for (b in sim.existingBodies())
			sim.onSpawn(b);

		// HUD on top of the gameplay scene
		hud = new HudDesign();
		s2d.addChild(hud);
		style.addObject(hud);
		style.sync();
	}

	/** Build a mesh for a spawned body. Extend this switch for new entities. */
	function meshForBody(b : PhysBody) : Null<h3d.scene.Mesh>
	{
		var sizes = b.getShapeSizes();
		if (sizes == null) return null;
		var prim : h3d.prim.Primitive = switch (b.name)
		{
			case "floor":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			case "cube":
				new h3d.prim.Cube(sizes.hx * 2, sizes.hy * 2, sizes.hz * 2, true);
			default:
				null;
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
		}
		m.mainPass.addShader(pbr);
		return new h3d.scene.Mesh(prim, m);
	}

	public function update(dt : Float)
	{
		sim.update(dt);    // shared simulation (fixed Hz) вЂ” same call as the server
		physRenderer.render(); // interpolated visuals every frame
		style.sync(dt);
	}
}
