package extract.utils;

import hxd.Key;

import shared.IUpdate;

/**
	Extensible keyboard movement controller (client-side input math).
	Reads WASD/Shift, eases a smoothed velocity, exposes the world-space
	direction for a given yaw. Knows nothing about the sim, the hero or
	the camera — the owner (PlayerControllerSystem) takes `dirWorld(yaw)`
	and publishes it as an intent.

	Smoothing is frame-rate independent (exponential), style of CameraFly.
**/
class MovementController implements IUpdate
{
	/** Base speed, world units per second. */
	public var speed : Float = 6;
	/** Speed multiplier while Shift is held. */
	public var fastMult : Float = 2;
	/** Invert horizontal input (A<->D). */
	public var invertX : Bool = false;
	/** Invert vertical input (W<->S). */
	public var invertZ : Bool = false;
	/** Movement inertia while accelerating: response rate per second. */
	public var moveSmooth : Float = 12;
	/** Deceleration rate when no input (higher = quicker stop). */
	public var stopSmooth : Float = 20;
	/** Below this speed (units/sec) the movement snaps to a full stop. */
	public var stopThreshold : Float = 0.05;

	/** Set by the owner when a jump key is pressed; consumed (reset) by the sim. */
	public var jumpRequested(default, null) : Bool = false;

	// smoothed velocity (world-space, updated against the last known yaw)
	var vel : h3d.Vector = new h3d.Vector();
	var lastYaw : Float = 0;
	var spaceWasDown : Bool = false;

	public function new() {}

	/** Flag a jump request (consumed by the owner, then auto-clears on read below). */
	public function requestJump() : Void
	{
		jumpRequested = true;
	}

	/** Read and clear the jump request. */
	public function consumeJump() : Bool
	{
		var j = jumpRequested;
		jumpRequested = false;
		return j;
	}

	public function update(dt : Float) : Void
	{
		// jump: fresh Space press only (no auto-repeat while held)
		if (Key.isDown(Key.SPACE) && !spaceWasDown) requestJump();
		spaceWasDown = Key.isDown(Key.SPACE);

		var sp = speed * (Key.isDown(Key.SHIFT) ? fastMult : 1);
		// local input: +x right, +z forward (matches camera yaw basis)
		var ix = 0.0;
		var iz = 0.0;
		if (Key.isDown(Key.W)) iz += 1;
		if (Key.isDown(Key.S)) iz -= 1;
		if (Key.isDown(Key.D)) ix += 1;
		if (Key.isDown(Key.A)) ix -= 1;
		if (invertX) ix = -ix;
		if (invertZ) iz = -iz;

		// rotate local input to world by yaw (forward = -Z at yaw 0)
		var sy = Math.sin(lastYaw);
		var cy = Math.cos(lastYaw);
		var wx = ix * cy - iz * sy;
		var wz = -ix * sy - iz * cy;

		var len = Math.sqrt(wx * wx + wz * wz);
		if (len > 1e-6) { wx /= len; wz /= len; wx *= sp; wz *= sp; }

		var k = 1 - Math.exp(-(len > 1e-6 ? moveSmooth : stopSmooth) * dt);
		vel.x += (wx - vel.x) * k;
		vel.z += (wz - vel.z) * k;
		// dead-snap to full stop below the threshold (kills micro-drift)
		if (len <= 1e-6 && vel.x * vel.x + vel.z * vel.z < stopThreshold * stopThreshold)
		{
			vel.x = 0;
			vel.z = 0;
		}
	}

	/** Remember the yaw the input was rotated by (call before update). */
	public function setYaw(yaw : Float) : Void
	{
		// re-express the smoothed velocity in the new yaw frame so the
		// direction doesn't jump when the camera turns
		var dy = yaw - lastYaw;
		if (dy != 0)
		{
			var s = Math.sin(dy);
			var c = Math.cos(dy);
			var vx = vel.x * c - vel.z * s;
			var vz = vel.x * s + vel.z * c;
			vel.x = vx;
			vel.z = vz;
		}
		lastYaw = yaw;
	}

	/** Current smoothed world-space direction, normalized (0,0 when idle). */
	public function dirWorld() : { x : Float, z : Float }
	{
		var l = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
		if (l < 1e-4) return { x : 0.0, z : 0.0 };
		return { x : vel.x / l, z : vel.z / l };
	}

	/** Eased move magnitude 0..1 (relative to base speed) — scales the intent. */
	public function magnitude() : Float
	{
		var l = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
		return l < 1e-4 ? 0 : l / speed;
	}

	/** Current smoothed speed magnitude (world units/sec). */
	public function speedNow() : Float
	{
		return Math.sqrt(vel.x * vel.x + vel.z * vel.z);
	}
}
