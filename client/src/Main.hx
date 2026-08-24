package;
import hxd.Res;

import extract.HeapsApp;

class Main
{
    public static function main()
    {
        trace("Hello, World! Client");
        hxd.Res.initPak();
        HeapsApp.app();
    }
}
