Get["FIRE7.m"];
LoadStart["tests/math/etalon/v2", 2];
LoadLRules["tests/math/temp/v2.dir", 2];
Burn[];
result = F[2, {-1, 1, 1, 1, 1, 1, 1}];
Put[result, "tests/math/temp/v2_F.m"];

