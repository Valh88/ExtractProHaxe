package extract.design;

import h2d.Flow;
import h2d.domkit.Object;

/** "SEARCH" button of the mode panel. */
@:uiComp("search-button")
class SearchButton extends Flow implements Object
{
	static var SRC =
		<search-button>
			<text id="btnText" class="search-text" x="60" y="12"/>
		</search-button>;

	public function new(?parent)
	{
		super(parent);
		initComponent();
		btnText.text = "SEARCH";
	}
}
