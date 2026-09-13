package extract.systems;

import shared.events.EventBus;
import shared.events.GameEvents.StatsUpdate;
import shared.systems.System;
import extract.design.HudDesign;

#if sys
import rnl.net.SocketHost;
import rnl.net.SocketClient;
#end

/**
	Client-side presentation system: reads FPS from Heaps Engine and ping
	from the RNL socket (if available), publishes StatsUpdate and
	immediately updates the HUD stats — self-contained, GamePlayView
	doesn't need to touch StatsUpdate at all.
**/
class StatisticSystem extends System
{
	static inline var UPDATE_INTERVAL : Float = 0.5;

	var elapsed : Float = 0;
	var hud : HudDesign;

	#if sys
	var socket : Null<SocketHost>;
	#end

	public function new(bus : EventBus, hud : HudDesign, ?socket : SocketHost)
	{
		super(bus, null, null, "Statistic");
		this.hud = hud;
		#if sys
		this.socket = socket;
		#end
		bus.subscribe(StatsUpdate, onStatsUpdate);
	}

	override public function update(dt : Float) : Void
	{
		elapsed += dt;
		if (elapsed < UPDATE_INTERVAL) return;
		elapsed -= UPDATE_INTERVAL;

		var fps = Std.int(h3d.Engine.getCurrent().fps + 0.5);

		var pingMs = 0;
		#if sys
		if (socket != null && socket.serverClient != null)
		{
			var sc : SocketClient = Std.downcast(socket.serverClient, SocketClient);
			if (sc != null && sc.peer != null)
				pingMs = sc.peer.minRtt;
		}
		#end

		bus.publish(new StatsUpdate(fps, pingMs));
	}

	function onStatsUpdate(e : StatsUpdate) : Void
	{
		if (hud != null && hud.stats != null)
		{
			hud.stats.setFps(e.fps);
			hud.stats.setPing(e.pingMs);
		}
	}

	override public function dispose() : Void
	{
		bus.unsubscribe(StatsUpdate, onStatsUpdate);
		super.dispose();
	}
}
