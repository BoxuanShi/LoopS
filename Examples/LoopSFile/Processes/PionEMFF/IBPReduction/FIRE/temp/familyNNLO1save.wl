
Get["/home/balth/Documents/fire7/FIRE7/FIRE7.m"];
LoadStart["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNNLO1", 1];
Burn[];
LoadTables["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNNLO1.tables"];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get["/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNNLO1.m"] /. d -> D;
tp1 >> "/media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/IBPReduction/FIRE/familyNNLO1save.m";
Quit[];
