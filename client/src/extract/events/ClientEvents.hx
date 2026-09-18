package extract.events;

import extract.models.HeroVisual;

/**
	Client-only: the local hero's HeroVisual was created and bound to physics.
	Published by ClientEntityFactory when the local hero body spawns.
	HeroVisualController subscribes and binds itself — the factory neither
	stores nor owns the visual, it only notifies.
**/
class LocalHeroSpawned
{
	public var visual : HeroVisual;

	public function new(visual : HeroVisual)
	{
		this.visual = visual;
	}
}