(*Paths*)
$LoopSInstallPath = DirectoryName[$InputFileName];
$LoopSScriptDirectory := Module[{cmd, script},
  cmd = Quiet@Check[$ScriptCommandLine, {}];
  script = If[ListQ[cmd] && Length[cmd] > 0, First[cmd], ""];
  If[StringQ[script] && FileExistsQ[script], DirectoryName[ExpandFileName[script]], Directory[]]
];
$NotebookDirectory = If[$FrontEnd === Null, $LoopSScriptDirectory,
  Quiet@Check[DirectoryName[NotebookFileName[]], Directory[]]
]


(*LoopS*)
Get[FileNameJoin[{$LoopSInstallPath, "LoopSNeatCore.m"}]];
With[{LoopS`Private`ins = $LoopSInstallPath, LoopS`Private`nbdd = $NotebookDirectory},
Parallel`Protected`AddInitCode[Parallel`Client`HoldCompound[
      Block[{LoopS`Private`nbd = LoopS`Private`nbdd},
      Get[FileNameJoin[{LoopS`Private`ins, "LoopSNeatCore.m"}]]]
      ]]
];
(* Parallel`Protected`addBadContext["LoopS`"]; *)
