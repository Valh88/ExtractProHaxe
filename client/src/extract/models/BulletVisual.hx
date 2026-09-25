package extract.models;

import h3d.scene.Mesh;
import h3d.scene.Object;

/**
	Projectile tracer: an elongated glowing capsule that rides the bullet
	body. Spawned by ClientEntityFactory.onBodyAdded, which binds the
	CONTAINER to the PhysRenderer — the renderer overwrites the bound
	object's transform every frame from the body's quaternion (identity for
	the sphere bullet), so the flight orientation is baked ONCE into the
	child mesh node instead. The direction never changes in flight
	(gravityScale = 0), so a one-time bake is exact for the whole lifetime.
**/
class BulletVisual extends Object
{
	/** Tracer length in meters (cylinder part; the caps add 2 × bullet radius). */
	public static var TRACER_LENGTH : Float = 0.7;
	/** Glow intensity of the tracer (PropsValues emissiveValue). */
	public static var EMISSIVE : Float = 0.8;

	/** The rendered tracer mesh — child node carrying the flight rotation. */
	public var mesh(default, null) : Mesh;

	public function new(parent : Object, radius : Float, dirX : Float, dirY : Float, dirZ : Float)
	{
		super(parent);
		var prim = new h3d.prim.Capsule(radius, TRACER_LENGTH, 8, h3d.prim.Capsule.Axis.Y);
		prim.addNormals();
		var m = h3d.mat.Material.create();
		// bright yellow tracer — matches the prototype projectile color
		m.color.set(1, 0.95, 0.2, 1);
		// a thin fast mover would smear the shadow map
		m.castShadows = false;
		var pbr = new h3d.shader.pbr.PropsValues();
		pbr.emissiveValue = EMISSIVE;
		m.mainPass.addShader(pbr);
		mesh = new Mesh(prim, m, this);
		var q = flightRotation(dirX, dirY, dirZ);
		mesh.setRotationQuat(q);
	}

	/**
		Rotation taking the capsule's long axis (+Y) onto the flight direction:
		a single rotation around cross(Y, dir) by the angle between them.
		Degenerate cases (dir along ±Y) have a zero axis and are handled
		explicitly — identity for +Y, a half turn around X for −Y.
	**/
	static function flightRotation(dirX : Float, dirY : Float, dirZ : Float) : h3d.Quat
	{
		var d = Math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
		if (d < 1e-9) return new h3d.Quat(); // no direction — keep +Y
		dirX /= d; dirY /= d; dirZ /= d;
		// cross((0,1,0), dir) = (dirZ, 0, -dirX); |cross| = sin(angle)
		var ax = dirZ, ay = 0.0, az = -dirX;
		var sinA = Math.sqrt(ax * ax + ay * ay + az * az);
		var cosA = dirY; // dot((0,1,0), dir)
		var q = new h3d.Quat();
		if (sinA < 1e-6)
		{
			if (cosA > 0) return q;
			q.initRotateAxis(1, 0, 0, Math.PI);
			return q;
		}
		q.initRotateAxis(ax, ay, az, Math.atan2(sinA, cosA));
		return q;
	}
}
