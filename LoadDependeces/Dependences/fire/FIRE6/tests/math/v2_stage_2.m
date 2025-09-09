SetDirectory["extra/LiteRed/Setup/"];
Get["LiteRed.m"];
$LiteRedMonitor = False;
SetDirectory["../../../"];
Get["FIRE6.m"];
Internal = {l, r};
External = {p, q};
Propagators = (-Power[##, 2]) & /@ {l - r, l, r, p - l, q - r, 
    p - l + r, q - r + l};
Replacements = {p^2 -> 0, q^2 -> 0, p q -> -1/2};
CreateNewBasis[v2, Directory -> "tests/math/temp/v2.dir"];
GenerateIBP[v2];
AnalyzeSectors[v2, {0, __}];
FindSymmetries[v2];
SetOptions[SolvejSector, Depth -> 0];
SolvejSector /@ UniqueSectors[v2];
DiskSave[v2];
