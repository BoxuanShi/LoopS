Get["FIRE7.m"];
LoadStart["tests/math/etalon/box", 1];
Burn[];
LoadRules["tests/math/etalon/box", 1];
EvaluateAndSave[{{1, {2, 2, 2, 2}}}, "tests/math/temp/box.tables"]
