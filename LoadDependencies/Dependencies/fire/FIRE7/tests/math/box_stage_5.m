Get["FIRE7.m"];
Internal = {k};
External = {p1, p2, p4};
Propagators = {-k^2, -(k + p1)^2, -(k + p1 + p2)^2, -(k + p1 + p2 + 
       p4)^2};
Replacements = {p1^2 -> 0, p2^2 -> 0, p4^2 -> 0, p1 p2 -> -S/2, 
   p2 p4 -> -T/2, p1 p4 -> (S + T)/2, S -> 1, T -> 1};
SYMMETRIES = {{2, 1, 4, 3}};
PrepareIBP[];
Prepare[AutoDetectRestrictions -> True, LI -> True];
SaveStart["tests/math/temp/boxs"];
