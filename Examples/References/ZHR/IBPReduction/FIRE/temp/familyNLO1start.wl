Get["/Users/balth/Library/Mathematica/Applications/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
Internal = {l1h}; 
External = {n, nb}; 
Propagators = {l1h*n, l1h^2, -mch^2 + (l1h + (n*nbkh)/2 - (n*nbp)/2 - (nb*np)/2)^2}; 
Replacements = {n^2 -> 0, nb^2 -> 0, n*nb -> 2}; 
PrepareIBP[];
Prepare[AutoDetectRestrictions->True,LI->True];
SaveStart["/Users/balth/Library/Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1"];
Quit[];
