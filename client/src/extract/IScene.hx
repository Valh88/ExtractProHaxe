package extract;

/** Common contract for scenes managed by SceneManager. */
interface IScene
{
	function update(dt : Float) : Void;
}