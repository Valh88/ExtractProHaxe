package extract.utils.animations;

/**
	Abstract base class for all animations. Handles timing (delay, duration,
	loop, reverse), easing, and lifecycle callbacks. Subclasses override
	`apply(progress)` to map the eased value onto their target.

	Timing flow:
	  delay → start → elapsed accumulates → apply(eased(t)) → complete
	  if loop: reset elapsed and repeat; if reverse: ping-pong direction
**/
abstract class AAnimation
{
	/** Target object (h2d.Object for visual animations, null for NumTween). */
	public var target(default, null) : Null<h2d.Object>;

	/** Total animation duration in seconds (excluding delay). */
	public var duration : Float;

	/** Elapsed time since animation started (after delay). */
	public var elapsed : Float = 0;

	/** Initial delay before the animation begins. */
	public var delay : Float = 0;

	/** If true, animation loops forever (reverse toggles each loop). */
	public var loop : Bool = false;

	/** If true, animation ping-pongs on each loop iteration. */
	public var reverse : Bool = false;

	/** Number of completed loops (reset on reset()). */
	public var loopCount(default, null) : Int = 0;

	/** Easing function: t ∈ [0,1] → curved output ∈ [0,1]. Defaults to linear. */
	public var easing : Float -> Float;

	/** Called when the animation finishes (once, not per loop). */
	public var onComplete : Null<Void -> Void>;

	/** Called every frame with the raw progress (0..1, before easing). */
	public var onUpdate : Null<Float -> Void>;

	/** Running state. */
	public var isRunning(default, null) : Bool = false;

	/** True after the animation has finished (once or all loops). */
	public var isComplete(default, null) : Bool = false;

	/** Is the animation paused? */
	public var isPaused(default, null) : Bool = false;

	var _reversed : Bool = false;

	/**
		@param target   h2d.Object to animate (or null for non-visual tweens)
		@param duration seconds (must be > 0)
		@param easing   easing function (null → linear)
	**/
	public function new(target : Null<h2d.Object>, duration : Float, ?easing : Float -> Float)
	{
		this.target = target;
		this.duration = duration > 0 ? duration : 0.001;
		this.easing = easing != null ? easing : Easing.linear;
	}

	/** Start (or restart) the animation. Returns `this` for chaining. */
	public function start() : AAnimation
	{
		isRunning = true;
		isComplete = false;
		isPaused = false;
		_reversed = false;
		elapsed = 0;
		loopCount = 0;
		return this;
	}

	/** Stop the animation. Preserves current state (can resume). */
	public function stop() : Void
	{
		isRunning = false;
		isPaused = false;
	}

	/** Pause the animation (can resume). */
	public function pause() : Void
	{
		if (isRunning && !isComplete) isPaused = true;
	}

	/** Resume a paused animation. */
	public function resume() : Void
	{
		if (isRunning && isPaused) isPaused = false;
	}

	/** Reset elapsed, loopCount, and completion state. Does not restart. */
	public function reset() : Void
	{
		elapsed = 0;
		loopCount = 0;
		isComplete = false;
		_reversed = false;
	}

	/**
		Advance the animation by `dt` seconds. Called by AnimationController.
		Handles delay, timing, loop/reverse logic, and calls apply().
	**/
	public function update(dt : Float) : Void
	{
		if (!isRunning || isComplete || isPaused) return;

		// delay phase
		if (delay > 0)
		{
			delay -= dt;
			if (delay > 0) return;
			dt = -delay; // consume leftover time
			delay = 0;
		}

		elapsed += dt;

		// compute progress (0..1)
		var raw : Float;
		var finished : Bool;

		if (elapsed >= duration)
		{
			raw = 1.0;
			finished = true;
		}
		else
		{
			raw = elapsed / duration;
			finished = false;
		}

		// reverse direction: ping-pong
		var t = _reversed ? 1.0 - raw : raw;

		// apply the eased value
		apply(easing(t));
		if (onUpdate != null) onUpdate(raw);

		if (finished) onFinished();
	}

	/** Current progress 0..1 (without easing, without reverse). */
	public function get_progress() : Float
	{
		return elapsed <= 0 ? 0.0 : (elapsed >= duration ? 1.0 : elapsed / duration);
	}

	// --- subclass hook ---

	/** Override: apply the eased value to the target. `t` is already eased (0..1). */
	abstract function apply(t : Float) : Void;

	// --- internal ---

	function onFinished() : Void
	{
		if (loop)
		{
			loopCount++;
			elapsed = 0;
			if (reverse) _reversed = !_reversed;
			return;
		}

		isRunning = false;
		isComplete = true;
		if (onComplete != null) onComplete();
	}
}
