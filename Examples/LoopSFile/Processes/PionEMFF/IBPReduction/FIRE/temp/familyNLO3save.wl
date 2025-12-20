
Get["/home/balth/.Mathematica/Applications/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
LoadStart["/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3", 3];
Burn[];
LoadTables[None];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3.m"] /. d -> D;
tp1 >> "/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3save.m";
Quit[];
