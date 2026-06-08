scriptDir = DirectoryName[ExpandFileName[First[$ScriptCommandLine]]];
Get[FileNameJoin[{scriptDir, "..", "..", "LoopS.m"}]];

PionEMFF = CreateProcess[
  "ProcessName" -> "PionEMFF",
  "loopmoms" -> {l1, l2},
  "extmomsind" -> {p, pp},
  "kinematics" -> {p^2 -> 0, pp^2 -> 0, p*pp -> 1/2},
  "extramoms" -> {p1, p2, p3, p4},
  "indices" -> {p, mu, "dummyindices", pp}
];

AlgebrasDefinition["PionEMFF"] := Module[{},
  Momentum[p1, D] = x1 Momentum[p, D];
  Momentum[p2, D] = x2 Momentum[p, D];
  Momentum[p3, D] = y1 Momentum[pp, D];
  Momentum[p4, D] = y2 Momentum[pp, D];
];

ClearProcess["PionEMFF"] := Module[{}, Nothing];

SetupProcess["PionEMFF"];
If[CurrentProcess["ProcessName"] =!= "PionEMFF", Print["PionEMFF setup failed."]; Exit[1]];
If[! DirectoryQ[ProcessPath], Print["PionEMFF process path was not created."]; Exit[1]];

Print["PionEMFF script example passed."];
Exit[0];
