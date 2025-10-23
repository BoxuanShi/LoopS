
Get["/home/balth/Documents/fire7/FIRE7/FIRE7.m"];
LoadStart["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO2", 2];
Burn[];
LoadTables["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO2.tables"];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO2.m"] /. d -> D;
tp1 >> "/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/ZHR/IBPReduction/FIRE/familyNLO2save.m";
Quit[];
