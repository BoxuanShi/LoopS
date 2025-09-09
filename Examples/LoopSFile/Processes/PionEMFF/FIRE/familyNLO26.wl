Get["/Users/balth/Downloads/LoopS/packages/fire/FIRE6/FIRE6.m"];
Internal = {l1}; 
External = {p, pp}; 
Propagators = {l1^2, (l1 - p*x2 + pp*y1 + pp*y2)^2, (l1 + p)^2}; 
Replacements = {p^2 -> 0, pp^2 -> 0, p*pp -> 1/2}; 
PrepareIBP[];
Prepare[AutoDetectRestrictions->True,LI->True];
SaveStart[ToString["/Users/balth/Downloads/LoopS/LoopSFile/Processes/PionEMFF/FIRE/familyNLO26"]];
Quit[];
