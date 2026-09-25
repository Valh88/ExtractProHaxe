package serv.systems;

import shared.GameData;
import shared.events.EventBus;
import shared.net.GameNet;
import shared.systems.System;

/**
	Server-side sun authority (the room-layer mirror of the client's
	SunSystem): owns the sun orbit PHASE and broadcasts it to every
	connected client via GameNet.sunUpdate.

	The server never computes sun DIRECTIONS — clients derive the light /
	disc / day-night look from the phase themselves (same trajectory math).
	Clients keep advancing the phase locally between syncs (dead reckoning),
	so the broadcast cadence only has to bound the drift, not carry smooth
	motion: a full cycle is minutes long, SYNC_INTERVAL seconds of drift are
	imperceptible. Late joiners receive the current phase within one
	SYNC_INTERVAL of their join (no join hooks needed).

	SERVER-ONLY room system (roomSystems): ticks once per host round.
**/
class SunSyncSystem extends System
{
	/** Initial orbit phase — must match the client's SunSystem.START_ANGLE. */
	public static inline var START_ANGLE : Float = 0;
	/** Default full-cycle length in seconds — must match the client's
		SunSystem.DEFAULT_DAY_LENGTH (cdb "World"."sunCycleSeconds" overrides). */
	public static var DEFAULT_DAY_LENGTH : Float = 600;
	/** Seconds between sun phase broadcasts. */
	public static var SYNC_INTERVAL : Float = 2.0;

	/** Current orbit phase, 0..2π (0 = noon peak). */
	public var sunAngle(default, null) : Float;

	/** Seconds for one full cycle. */
	public var dayLength(default, null) : Float;

	var gameNet : Null<GameNet>;
	var sinceSync : Float = SYNC_INTERVAL; // fire the first sync immediately
	var firstSyncSent : Bool = false;

	public function new(bus : EventBus, ?gd : GameData, gameNet : GameNet)
	{
		super(bus, null, gd, "SunSync");
		this.gameNet = gameNet;

		sunAngle = START_ANGLE;
		dayLength = DEFAULT_DAY_LENGTH;
		// same optional cdb override the client's SunSystem reads
		if (gd != null)
		{
			var l = gd.line("World");
			var v : Dynamic = l == null ? null : Reflect.field(l, "sunCycleSeconds");
			if (v != null && Std.isOfType(v, Float)) dayLength = v;
		}
	}

	override public function update(dt : Float) : Void
	{
		// advance the authoritative phase at the same pace the clients tick
		sunAngle = (sunAngle + dt * (Math.PI * 2) / dayLength) % (Math.PI * 2);

		sinceSync += dt;
		if (sinceSync >= SYNC_INTERVAL)
		{
			sinceSync = 0;
			if (gameNet != null)
			{
				if (!firstSyncSent)
				{
					firstSyncSent = true;
					trace('SERVER sun sync start: phase=' + Math.round(sunAngle * 180 / Math.PI) + '° dayLength=' + dayLength + 's (every ' + SYNC_INTERVAL + 's)');
				}
				gameNet.sunUpdate(sunAngle, dayLength);
			}
		}
	}

	override public function dispose() : Void
	{
		gameNet = null;
		super.dispose();
	}
}
