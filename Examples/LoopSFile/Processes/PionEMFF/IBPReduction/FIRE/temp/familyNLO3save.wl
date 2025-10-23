
Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/LoadDependencies/Dependencies/fire/FIRE6/FIRE6.m"];
LoadStart["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3", 3];
Burn[];
LoadTables[None];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3.m"] /. d -> D;
tp1 >> "/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNLO3save.m";
Quit[];
