package serv.room;

import shared.GameData;
import serv.systems.DemoLogSystem;

/**
	Concrete room using the current SimWorld gameplay unchanged (floor, auto
	cubes, hero/bullet sim systems). Demonstrates BOTH attachment points:

	- TO THE WORLD: inherited — the base SimWorld already registers the shared
	  sim systems (Hero, Bullet) inside `world`.
	- TO THE ROOM: a DemoLogSystem is added to `roomSystems` to prove that
	  server-only room logic ticks in the pool alongside the world.
**/
class DemoRoom extends Room
{
	public function new(id : String, gd : GameData, port : Int)
	{
		super(id, "demo", gd, port);
		// world physics log: the room attaches its own logger to the world
		// (dump is called by Room.tick each tick)
		logger = new StateLogger();
		//world.phys.addConsumer(logger);
		// server-only logic layer of this room (mirror of client view systems)
		roomSystems.add(new DemoLogSystem(bus));
	}
}
