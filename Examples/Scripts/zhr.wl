scriptDir = DirectoryName[ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
]];
projectRoot = ParentDirectory[ParentDirectory[scriptDir]];
Get[FileNameJoin[{projectRoot, "LoopS.m"}]];

ZHR = CreateProcess[
  "ProcessName" -> "ZHR",
  "loopmoms" -> {l1h},
  "extmomsind" -> {n, nb},
  "kinematics" -> {n^2 -> 0, nb^2 -> 0, n*nb -> 2},
  "extramoms" -> {l1hc, p, k, kh, v}
];

AlgebrasDefinition["ZHR"] := Module[{},
  Momentum[p, D] = np/2 Momentum[nb, D] + lamb^2 nbp/2 Momentum[n, D];
  Momentum[k, D] = lamb^2 Momentum[kh, D];
  Momentum[v, D] = 1/2 Momentum[nb, D] + 1/2 Momentum[n, D];
  Momentum[l1hc, D] = SPD[n, l1h]/2 Momentum[nb, D] +
    lamb^2 SPD[nb, l1h]/2 Momentum[n, D] +
    lamb (Momentum[l1h, D] - SPD[n, l1h]/2 Momentum[nb, D] - SPD[nb, l1h]/2 Momentum[n, D]);
  mc = lamb mch;
  SPD[kh, kh] = kh2;
  SPD[kh, n] = nkh;
  SPD[kh, nb] = nbkh;
];

ClearProcess["ZHR"] := Module[{}, Nothing];

SetupProcess["ZHR"];
If[CurrentProcess["ProcessName"] =!= "ZHR", Print["ZHR setup failed."]; Exit[1]];
If[! DirectoryQ[ProcessPath], Print["ZHR process path was not created."]; Exit[1]];

Print["ZHR script example passed."];
Exit[0];
