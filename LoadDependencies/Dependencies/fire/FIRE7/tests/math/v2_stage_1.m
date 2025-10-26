Get["FIRE7.m"];
Internal = {l, r};
External = {p, q};
Propagators = (- Power[##, 2]) & /@ {l - r, l, r, p - l, q - r, 
    p - l + r, q - r + l};
Replacements = {p^2 -> 0, q^2 -> 0, p q -> -1/2};
PrepareIBP[];
Prepare[AutoDetectRestrictions -> True, LI -> True];
SaveStart["tests/math/temp/v2"];
