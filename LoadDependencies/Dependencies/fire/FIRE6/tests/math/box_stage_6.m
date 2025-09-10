Get["FIRE6.m"];
LoadStart["tests/math/etalon/boxs", 1];
Burn[];
result = F[1, {2, 2, 2, 2}];
Put[result, "tests/math/temp/box_Fs.m"];
