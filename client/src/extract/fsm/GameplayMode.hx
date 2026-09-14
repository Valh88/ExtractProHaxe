package extract.fsm;

/**
	Client gameplay UI states for `GameplayFsm`.
	Extensible: add a case here, an `AState` subclass, and one `registerState`.
**/
enum GameplayMode { fsIngame; fsSettings; }