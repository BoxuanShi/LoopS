(*Paths*)
$LoopSInstallPath = DirectoryName[$InputFileName];
$NotebookDirectory = DirectoryName[NotebookFileName[]]


(*LoopS*)
Get[FileNameJoin[{$LoopSInstallPath, "LoopSNeatCore.m"}]];
With[{LoopS`Private`ins = $LoopSInstallPath, LoopS`Private`nbdd = $NotebookDirectory},
Parallel`Protected`AddInitCode[Parallel`Client`HoldCompound[
      Block[{LoopS`Private`nbd = LoopS`Private`nbdd},
      Get[FileNameJoin[{LoopS`Private`ins, "LoopSNeatCore.m"}]]]
      ]]
];
(* Parallel`Protected`addBadContext["LoopS`"]; *)