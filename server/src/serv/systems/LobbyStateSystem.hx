package serv.systems;

import shared.systems.System;
import shared.events.EventBus;
import serv.room.LobbyRoom;

/**
	Lobby-only room system: logs the lobby state (player count) about once per
	second. Runs in `roomSystems` (NOT the sim — a lobby has no world), so it
	ticks once per host round like any server-only room logic.
**/
class LobbyStateSystem extends System
{
	var acc : Float = 0;
	var lobby : LobbyRoom;

	public function new(bus : EventBus, lobby : LobbyRoom)
	{
		super(bus, null, null, "LobbyState");
		this.lobby = lobby;
	}

	override public function update(dt : Float) : Void
	{
		acc += dt;
		if (acc < 1.0) return;
		acc -= 1.0;
		trace('LOBBY "' + lobby.id + '" players=' + Lambda.count(lobby.players)
			+ ' ready=' + readyCount() + ' state=' + lobby.state);
	}

	function readyCount() : Int
	{
		var n = 0;
		for (p in lobby.players)
			if (p.ready) n++;
		return n;
	}
}