
Get["/Users/balth/Library/Mathematica/Applications/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
LoadStart["/Users/balth/Library/Mathematica/Applications/LoopS/Examples/Notebook/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1", 1];
Burn[];
LoadTables[None];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/Users/balth/Library/Mathematica/Applications/LoopS/Examples/Notebook/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1.m"] /. d -> D;
tp1 >> "/Users/balth/Library/Mathematica/Applications/LoopS/Examples/Notebook/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1save.m";
Quit[];
