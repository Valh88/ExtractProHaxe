package test;

/**
	utest runner — test cases are auto-discovered from `test/*Test.hx`
	(see `TestDiscovery`), so new test files need no runner edits.
**/
class Runner
{
	public static function main()
	{
		var runner = new utest.Runner();

		var cases : Array<utest.Test> = TestDiscovery.cases();
		for (c in cases) runner.addCase(c);

		utest.ui.Report.create(runner);
		runner.run();
	}
}