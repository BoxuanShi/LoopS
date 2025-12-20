
Get["/home/balth/.Mathematica/Applications/LoopS/LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m"];
LoadStart["/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO2", 2];
Burn[];
LoadTables[None];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO2.m"] /. d -> D;
tp1 >> "/home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO2save.m";
Quit[];
