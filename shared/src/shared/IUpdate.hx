package shared;

/** Universal per-frame/tick update contract (client + server). */
interface IUpdate
{
	function update(dt : Float) : Void;
}