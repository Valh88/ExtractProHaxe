#if sys
package extract.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.events.GameEvents.BulletFired;
import shared.events.GameEvents.HeroMoveIntent;
import shared.net.GameNet;
import shared.systems.System;
import extract.fsm.GameplayMode;
import extract.fsm.GameplayState;

/**
	Client-side transport layer (HL only, used under `#if sys`): subscribes to
	one-shot input events on the sim's shared bus and forwards them to the
	server via the GameNet mirror. Continuous state is NOT routed here — the
	server owns it (HeroObject `@:s`).

	The playerId is NOT forwarded — the server resolves it from the RPC
	caller's peer id (`__rpcCaller`), so the client can never address another
	player's hero.
**/
class ClientTransportSystem extends System
{
	var gameNet : Null<GameNet>;

	public function new(bus : EventBus, ?gd : GameData, ?gameNet : GameNet)
	{
		super(bus, null, gd, "ClientTransport");
		this.gameNet = gameNet;
		bus.subscribe(HeroMoveIntent, onHeroMove);
		bus.subscribe(BulletFired, onBulletFire);
	}

	function onHeroMove(e : HeroMoveIntent) : Void
	{
		// Settings open: block actual movement, but let a ZEROED intent (the
		// stop signal sent on the fsSettings transition) through — otherwise
		// the server keeps its last non-zero intent and the authoritative
		// hero walks forever while the local view is frozen.
		if (GameplayState.get().current == GameplayMode.fsSettings
			&& (e.mag > 0 || e.dirX != 0 || e.dirZ != 0)) return;
		if (gameNet != null) gameNet.heroInput(e.dirX, e.dirZ, e.yaw, e.mag, e.jump);
	}

	function onBulletFire(e : BulletFired) : Void
	{
		if (gameNet != null) gameNet.fireBullet(e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
	}

	override public function dispose() : Void
	{
		bus.unsubscribe(HeroMoveIntent, onHeroMove);
		bus.unsubscribe(BulletFired, onBulletFire);
		gameNet = null;
		super.dispose();
	}
}
#end