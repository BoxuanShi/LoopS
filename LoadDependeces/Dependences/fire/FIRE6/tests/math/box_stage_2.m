Get["FIRE6.m"];
LoadStart["tests/math/etalon/box", 1];
Burn[];
result = F[1, {2, 2, 2, 2}];
Put[result, "tests/math/temp/box_F.m"];
list = MasterIntegrals[];
Internal = {k};
External = {p1, p2, p4};
Propagators = {-k^2, -(k + p1)^2, -(k + p1 + p2)^2, -(k + p1 + p2 +
       p4)^2};
Replacements = {p1^2 -> 0, p2^2 -> 0, p4^2 -> 0, p1 p2 -> -S/2,
   p2 p4 -> -T/2, p1 p4 -> (S + T)/2, S -> 1, T -> 1};
WriteRules[list, "tests/math/temp/box"];
