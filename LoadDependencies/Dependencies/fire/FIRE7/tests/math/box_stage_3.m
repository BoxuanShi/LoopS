Get["FIRE7.m"];
LoadStart["tests/math/etalon/box", 1];
Burn[];
LoadRules["tests/math/etalon/box", 1];
result = F[1, {2, 2, 2, 2}];
Put[result, "tests/math/temp/box_Fr.m"];
