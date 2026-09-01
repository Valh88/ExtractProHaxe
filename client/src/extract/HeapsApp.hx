package extract;

import h3d.Vector;
import hxd.App;

import phys.core.PhysBody;
import phys.core.PhysCore;
import phys.render.PhysRenderer;

import shared.SimWorld;
import extract.views.LobbyView;

class HeapsApp extends App
{

	var sim : SimWorld;
	var renderer : PhysRenderer;
	var lobbyView : LobbyView;

	/** Global domkit style shared by all views (loads ui/lobby.css once). */
	public var uiStyle : h2d.domkit.Style;

	override function init()
	{
		// app-wide UI style: first thing so every view can style.addObject()
		uiStyle = new h2d.domkit.Style();
		uiStyle.load(hxd.Res.load("ui/lobby.css"));

		// 1) LobbyView becomes the root 3D scene (s3d) of the whole lobby
		lobbyView = new LobbyView(s2d, uiStyle);
		setScene(lobbyView);

		// project-wide screen-space AO (PBR renderer only)
		lobbyView.renderer.effects.push(new extract.gfx.ScalableAO());

		// shared simulation — same class the server runs
		sim = new SimWorld();

		// CLIENT consumer: maps each PhysBody to a mesh and interpolates it
		renderer = new PhysRenderer();
		sim.phys.addConsumer(renderer);

		// when the shared logic spawns a body, the client decides how to draw it
		sim.onSpawn = b ->
		{
			var mesh = meshForBody(b);
			if (mesh != null)
			{
				s3d.addChild(mesh);
				renderer.bind(b, mesh);
			}
		};
		// draw the initial scene too (created before onSpawn was set)
		for (b in sim.existingBodies())
			sim.onSpawn(b);
	}

	override function update(dt : Float)
	{
		super.update(dt);

		sim.update(dt);    // shared simulation (fixed Hz) — same call as the server
		renderer.render(); // interpolated visuals every frame
		lobbyView.update(dt); // domkit style sync
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

	override function loadAssets(done) 
	{
        #if sys
            hxd.Res.initLocal();
            done();
        #else
            new hxd.fmt.pak.Loader(s2d, done);
        #end
	}

	public static function app()
	{
		// PBR renderer (requires HashLink or WebGL 2.0)
		h3d.mat.MaterialSetup.current = new h3d.mat.PbrMaterialSetup();
		new HeapsApp();
	}
}
