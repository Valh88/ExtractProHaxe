package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** Small mode selector icon (e.g. Solo "1" / Party "3"). */
@:uiComp("mode-icon")
class ModeIcon extends Flow implements Object
{
	@:p public var label : String = "";

	static var SRC =
		<mode-icon>
			<text id="txt" class="mode-icon-label" x="20" y="18"/>
		</mode-icon>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		txt.text = label;
	}
}
