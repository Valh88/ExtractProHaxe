package extract.utils;

import shared.IUpdate;

/**
	Extensible first-person camera controller. Pure math/params — no input,
	no systems: the camera is injected once at construction, the owner
	(e.g. PlayerCameraSystem) feeds it yaw/pitch deltas and a target eye
	position each frame via `update(dt, ax, ay, az)`.

	Extension points: override `computeOffset` (shoulder/boom/FPV), override
	`applyTo` (extra post-processing like tilt/roll), tune any public field
	at runtime (cfg-driven tuning, hotkeys).

	Smoothing is frame-rate independent (exponential).
**/
class CameraController implements IUpdate
{
	// --- placement ---
	/** Eye height above the anchor point (world units). */
	public var eyeHeight : Float = 1.6;
	/** Forward offset of the eye from the anchor along the view dir (0 = at anchor). */
	public var forwardOffset : Float = 0;
	/** Right-side offset (positive = over right shoulder). */
	public var sideOffset : Float = 0;

	// --- look ---
	/** Mouse sensitivity: radians per pixel of drag. */
	public var sensitivity : Float = 0.005;
	/** User-facing multiplier on top of `sensitivity` (1 = default). */
	public var sensitivityMult : Float = 1.0;
	/** Pitch clamp in radians (~89°) — camera never flips over the poles. */
	public var maxPitch : Float = 1.5533;
	/** Invert vertical look. */
	public var invertY : Bool = false;
	/** Invert horizontal look (mouse right -> camera left). */
	public var invertX : Bool = false;
	/** Look inertia while dragging: response rate per second (higher = tighter). */
	public var lookSmooth : Float = 25;

	// --- follow ---
	/** Position follow rate per second (higher = snappier). 0 = snap instantly. */
	public var followRate : Float = 18;
	/** Field of view in degrees. */
	public var fov : Float = 75;
	/** Roll around the view axis, radians (drift/tilt effects). */
	public var roll : Float = 0;

	// --- state (yaw/pitch survive rebinds; set externally for respawn) ---
	public var yaw : Float = 0;
	public var pitch : Float = 0;

	// internal smoothed values
	var sYaw : Float = 0;
	var sPitch : Float = 0;
	var hasAngles : Bool = false;
	var sPos : h3d.Vector = new h3d.Vector();

	/** Current world-space eye position (valid after `update`). */
	public var eye(default, null) : h3d.Vector = new h3d.Vector();

	/** The camera this controller drives (injected once). */
	public var cam(default, null) : h3d.Camera;

	/** Anchor point the camera follows (player eye base, world space). Set before update(). */
	public var anchor : h3d.Vector = new h3d.Vector();

	public function new(cam : h3d.Camera)
	{
		this.cam = cam;
	}

	/**
		Advance look angles by raw mouse deltas (pixels) and smooth them.
		Call before `update`.
	**/
	public function addLook(dx : Float, dy : Float) : Void
	{
		yaw += (invertX ? dx : -dx) * sensitivity * sensitivityMult;
		pitch += (invertY ? dy : -dy) * sensitivity * sensitivityMult;
		if (pitch > maxPitch) pitch = maxPitch;
		if (pitch < -maxPitch) pitch = -maxPitch;
		if (!hasAngles) { sYaw = yaw; sPitch = pitch; hasAngles = true; }
	}

	/**
		Compute the eye position and orientation for this frame and apply
		them to the injected camera. Set `anchor` (player eye base, world
		space) before calling.
	**/
	public function update(dt : Float) : Void
	{
		var ax = anchor.x, ay = anchor.y, az = anchor.z;
		// ease actual angles toward the input targets
		var k = lookSmooth > 0 ? 1 - Math.exp(-lookSmooth * dt) : 1;
		sYaw += (yaw - sYaw) * k;
		sPitch += (pitch - sPitch) * k;

		// view basis from yaw/pitch (Y-up, forward = -Z at yaw 0)
		var cp = Math.cos(sPitch);
		var fx = -Math.sin(sYaw) * cp;
		var fy = Math.sin(sPitch);
		var fz = -Math.cos(sYaw) * cp;
		// right = up x forward (Y-up): (0,1,0) x (fx,fy,fz) = (fz, 0, -fx)
		var rx = fz;
		var rz = -fx;

		var off = computeOffset(fx, fy, fz, rx, rz);
		var ex = ax + off.x + rx * sideOffset;
		var ey = ay + off.y;
		var ez = az + off.z + rz * sideOffset;

		// position smoothing (skip on first frame / after snap)
		if (followRate <= 0 || !hasAngles)
		{
			sPos.set(ex, ey, ez);
		}
		else
		{
			var kp = 1 - Math.exp(-followRate * dt);
			sPos.x += (ex - sPos.x) * kp;
			sPos.y += (ey - sPos.y) * kp;
			sPos.z += (ez - sPos.z) * kp;
		}
		eye.set(sPos.x, sPos.y, sPos.z);

		cam.pos.set(sPos.x, sPos.y, sPos.z);
		cam.target.set(sPos.x + fx, sPos.y + fy, sPos.z + fz);
		applyTo();
		if (cam.fovY != fov) cam.fovY = fov;
	}

	/**
		Extension hook: offset from the anchor point before side/forward
		application. Default: zero (anchor is already the eye base).
	**/
	function computeOffset(fx : Float, fy : Float, fz : Float, rx : Float, rz : Float) : { x : Float, y : Float, z : Float }
	{
		return { x : 0.0, y : eyeHeight, z : 0.0 };
	}

	/**
		Extension hook after pos/target are set — add roll, shake, tilt etc.
	**/
	function applyTo() : Void
	{
		if (roll != 0)
		{
			// rotate the up vector around the view axis (Rodrigues)
			var up = cam.up;
			var vx = cam.target.x - cam.pos.x, vy = cam.target.y - cam.pos.y, vz = cam.target.z - cam.pos.z;
			var vl = Math.sqrt(vx * vx + vy * vy + vz * vz);
			if (vl > 1e-6)
			{
				vx /= vl; vy /= vl; vz /= vl;
				var c = Math.cos(roll), s = Math.sin(roll);
				var dot = up.x * vx + up.y * vy + up.z * vz;
				var cx = vy * up.z - vz * up.y, cy = vz * up.x - vx * up.z, cz = vx * up.y - vy * up.x;
				up.x = up.x * c + cx * s + vx * dot * (1 - c);
				up.y = up.y * c + cy * s + vy * dot * (1 - c);
				up.z = up.z * c + cz * s + vz * dot * (1 - c);
			}
		}
	}

	/** Snap all smoothing state (call on respawn/teleport). */
	public function snap() : Void
	{
		hasAngles = false;
	}
}
