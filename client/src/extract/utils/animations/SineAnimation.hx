package extract.utils.animations;

/**
	Continuous sine oscillator that plugs into the existing AnimationController.
	Extends AAnimation so it can be managed (start/stop/pause) alongside
	other animations, but overrides update() to bypass duration/loop logic
	— the wave runs forever until stopped.

	Subclass and override `compute(t)` for custom waveforms (triangle,
	square, noise, etc.). The `value` field carries the current output.

	Usage:
	  var sway = new SineAnimation(0.003, 1.5); // 3mm amplitude, 1.5 rad/s
	  ctrl.add(sway);                            // register with AnimationController
	  // each frame ctrl.update(dt) advances it
	  weapon.x = baseX + sway.value;
**/
class SineAnimation extends AAnimation
{
	/** Peak displacement from center (the wave output ranges [-amp, +amp]). */
	public var amplitude : Float;

	/** Angular frequency in radians per second. */
	public var frequency : Float;

	/** Phase offset in radians (shifts the wave start). */
	public var phase : Float;

	/** Center value (bias added on top of the sine output). */
	public var offset : Float;

	/** Current computed value — read this each frame after ctrl.update(). */
	public var value(default, null) : Float;

	/**
		@param amplitude peak displacement
		@param frequency angular speed in rad/s
		@param phase     phase offset in radians (default 0)
		@param offset    center bias (default 0)
	**/
	public function new(amplitude : Float, frequency : Float, phase : Float = 0, offset : Float = 0)
	{
		super(null, 1.0, null); // target=null (like NumTween), duration irrelevant
		this.amplitude = amplitude;
		this.frequency = frequency;
		this.phase = phase;
		this.offset = offset;
		this.value = offset;
		this.loop = true;
	}

	/** Continuous — never completes, ignores duration. */
	override public function update(dt : Float) : Void
	{
		if (!isRunning || isPaused) return;
		elapsed += dt;
		apply(elapsed);
		if (onUpdate != null) onUpdate(elapsed);
	}

	/** Compute the waveform and store in `value`. */
	function apply(t : Float) : Void
	{
		value = offset + amplitude * compute(t * frequency + phase);
	}

	/** Core waveform. Input is time in radians. Override for custom shapes.
		Must return a value in [-1, 1]. */
	function compute(t : Float) : Float
	{
		return Math.sin(t);
	}
}

/**
	Triangle wave — linear ramp between -1 and +1.
	Good for smooth mechanical sway without the sine "slow at peaks" feel.
**/
class TriangleSine extends SineAnimation
{
	public function new(amplitude : Float, frequency : Float, phase : Float = 0, offset : Float = 0)
	{
		super(amplitude, frequency, phase, offset);
	}

	override function compute(t : Float) : Float
	{
		return 2.0 / Math.PI * Math.asin(Math.sin(t));
	}
}
