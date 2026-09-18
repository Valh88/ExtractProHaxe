package extract.systems;

import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;
import extract.events.ClientEvents.LocalHeroSpawned;
import extract.models.HeroVisual;
import extract.utils.CameraController;
import extract.utils.MovementController;
import extract.utils.animations.AnimationController;
import extract.utils.animations.SineAnimation;
import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.AimStateChanged;

/**
	Manages hero visuals: ADS blend, weapon smoothing, idle sway,
	camera anchor sync, and FOV. Separated from PlayerControllerSystem
	to keep input logic clean.

	Usage:
	  heroVisCtrl = new HeroVisualController(bus, gd);
	  heroVisCtrl.bind(hero);  // when hero body spawns
	  // each frame:
	  heroVisCtrl.update(dt, camCtrl, moveCtrl);
**/
class HeroVisualController
{
	public var hero(default, null) : Null<HeroVisual>;

	/** Bullet spawn clearance along the fire direction (cached from cdb). */
	public var spawnAhead : Float = 0.6;

	// --- ADS ---
	public var adsBlend(default, null) : Float = 0;
	var defaultFov : Float = 75;
	var adsFov : Float = 60;
	var adsSpeed : Float = 0.15;
	var adsSensMult : Float = 0.5;
	var defaultSensitivity : Float = 0.005;
	var lastAiming : Bool = false;

	// --- weapon smoothing ---
	var weaponSmooth : Float = 15;
	var sWpnPitch : Float = 0;
	var sWpnYaw : Float = 0;
	var wpnHasState : Bool = false;

	// --- idle sway ---
	var wpnAnim : AnimationController;
	var swayOsc : SineAnimation;
	var breathOsc : SineAnimation;
	var rollOsc : SineAnimation;
	var bobOsc : SineAnimation;
	var wpnMoveSwayMult : Float = 1.5;

	var bus : EventBus;
	var gd : GameData;

	public function new(bus : EventBus, gd : GameData)
	{
		this.bus = bus;
		this.gd = gd;
		bus.subscribe(LocalHeroSpawned, onLocalHeroSpawned);

		wpnAnim = new AnimationController();
		swayOsc = new SineAnimation(0.003, 1.5);
		breathOsc = new SineAnimation(0.002, 1.2);
		rollOsc = new SineAnimation(0.004, 1.0);
		bobOsc = new SineAnimation(0.004, 8.0);
		wpnAnim.add(swayOsc);
		wpnAnim.add(breathOsc);
		wpnAnim.add(rollOsc);
		wpnAnim.add(bobOsc);
	}

	/** Self-bind when the local hero's visual spawns (factory -> bus). */
	function onLocalHeroSpawned(e : LocalHeroSpawned) : Void
	{
		if (e.visual != null) bind(e.visual);
	}

	/** Bind to a new hero visual. Reads all CDB tuning once. */
	public function bind(v : HeroVisual) : Void
	{
		hero = v;

		defaultFov = gd.req("Camera", "fov");
		adsFov = gd.req("Camera", "adsFov");
		adsSpeed = gd.req("Camera", "adsSpeed");
		adsSensMult = gd.req("Camera", "adsSensMult");
		defaultSensitivity = gd.req("Camera", "sensitivity");
		weaponSmooth = gd.req("Camera", "weaponSmooth");
		spawnAhead = gd.req("Hero", "heroRadius") + gd.req("Bullet", "radius") + 0.05;

		// reset weapon smoothing state
		sWpnPitch = 0;
		sWpnYaw = 0;
		wpnHasState = false;
		adsBlend = 0;
	}

	/** Unbind hero (on death / disconnect). */
	public function unbind() : Void
	{
		hero = null;
	}

	/** Snap ADS blend to hip and restore default FOV. */
	public function snapToHip(camCtrl : CameraController) : Void
	{
		adsBlend = 0;
		camCtrl.fov = defaultFov;
	}

	/** Read sensitivity scaled by ADS. Call before camCtrl.addLook. */
	public function getSensitivity() : Float
	{
		return defaultSensitivity * (1.0 - adsBlend * (1.0 - adsSensMult));
	}

	/** Advance ADS blend, weapon smoothing, sway, camera anchor, FOV.
		ADS only active when GameplayState == fsIngame. */
	public function update(dt : Float, camCtrl : CameraController, moveCtrl : MovementController) : Void
	{
		if (hero == null) return;

		var inGameplay = GameplayState.get().current == GameplayMode.fsIngame;

		// --- ADS blend (only in gameplay) ---
		if (inGameplay)
		{
			var isAiming = hxd.Key.isDown(hxd.Key.MOUSE_RIGHT);
			var adsTarget : Float = isAiming ? 1.0 : 0.0;
			var adsDelta = adsTarget - adsBlend;
			if (adsDelta != 0)
			{
				var k = adsSpeed > 0 ? dt / adsSpeed : 1.0;
				if (k > 1) k = 1;
				adsBlend += adsDelta * k;
			}
			if (isAiming != lastAiming)
			{
				lastAiming = isAiming;
				bus.publish(new AimStateChanged(isAiming));
			}
		}
		else
		{
			// not gameplay — force hip
			if (adsBlend != 0) snapToHip(camCtrl);
		}

		// --- camera anchor sync ---
		var ca = hero.cameraAnchor;
		ca.x = camCtrl.eye.x;
		ca.y = camCtrl.eye.y;
		ca.z = camCtrl.eye.z;

		var kw = weaponSmooth > 0 ? 1 - Math.exp(-weaponSmooth * dt) : 1;
		if (!wpnHasState)
		{
			sWpnPitch = camCtrl.pitch;
			sWpnYaw = camCtrl.yaw;
			wpnHasState = true;
		}
		else
		{
			sWpnPitch += (camCtrl.pitch - sWpnPitch) * kw;
			sWpnYaw += (camCtrl.yaw - sWpnYaw) * kw;
		}
		ca.setRotation(sWpnPitch, sWpnYaw, 0);

		// --- weapon sway ---
		wpnAnim.update(dt);
		var idle = 1.0 - adsBlend;
		var moving = moveCtrl.magnitude();
		var moveBoost = 1.0 + moving * wpnMoveSwayMult;

		var sx = swayOsc.value * idle * moveBoost;
		var sy = breathOsc.value * idle * moveBoost;
		var sr = rollOsc.value * idle * moveBoost;
		var bob = bobOsc.value * moving * idle;

		// apply weapon transform
		var w = hero.mainWeapon;
		var b = adsBlend;
		w.x = HeroVisual.HIP_X + (HeroVisual.ADS_X - HeroVisual.HIP_X) * b + sx;
		w.y = HeroVisual.HIP_Y + (HeroVisual.ADS_Y - HeroVisual.HIP_Y) * b + sy + bob;
		w.z = HeroVisual.HIP_Z + (HeroVisual.ADS_Z - HeroVisual.HIP_Z) * b;
		w.setScale(HeroVisual.HIP_SCALE + (HeroVisual.ADS_SCALE - HeroVisual.HIP_SCALE) * b);
		w.setRotation(-Math.PI / 2 + sr, -Math.PI / 2, 0);

		// --- FOV ---
		camCtrl.fov = defaultFov + (adsFov - defaultFov) * b;
	}
}
