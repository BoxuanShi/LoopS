Get["/Users/balth/Library/Mathematica/Applications/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
Internal = {l1}; 
External = {p, pp}; 
Propagators = {l1^2, (l1 + p*x1)^2, (l1 + pp*y1 + pp*y2)^2}; 
Replacements = {p^2 -> 0, pp^2 -> 0, p*pp -> 1/2}; 
PrepareIBP[];
Prepare[AutoDetectRestrictions->True,LI->True];
SaveStart["/Users/balth/Library/Mathematica/Applications/LoopS/Examples/Notebook/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3"];
Quit[];
