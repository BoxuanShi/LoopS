
Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/LoadDependencies/Dependencies/fire/FIRE6/FIRE6.m"];
LoadStart["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1", 1];
Burn[];
LoadTables[None];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1.m"] /. d -> D;
tp1 >> "/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO1save.m";
Quit[];
