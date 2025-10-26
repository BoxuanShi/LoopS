Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
Internal = {l1}; 
External = {p, pp}; 
Propagators = {l1^2, (l1 + p*x1)^2, (l1 - p*x2 + pp*y1)^2}; 
Replacements = {p^2 -> 0, pp^2 -> 0, p*pp -> 1/2}; 
PrepareIBP[];
Prepare[AutoDetectRestrictions->True,LI->True];
SaveStart["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO2"];
Quit[];
