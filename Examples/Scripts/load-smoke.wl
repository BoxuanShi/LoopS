scriptDir = DirectoryName[ExpandFileName[First[$ScriptCommandLine]]];
Get[FileNameJoin[{scriptDir, "..", "..", "LoopS.m"}]];

expectedRoot = ExpandFileName[FileNameJoin[{scriptDir, "..", ".."}]];
If[FileNameSplit[ExpandFileName[$LoopSInstallPath]] =!= FileNameSplit[expectedRoot],
  Print["Unexpected $LoopSInstallPath: ", $LoopSInstallPath];
  Exit[1]
];

If[! StringQ[$NotebookDirectory] || ! DirectoryQ[$NotebookDirectory],
  Print["Invalid script work base: ", $NotebookDirectory];
  Exit[1]
];

If[! DirectoryQ[LoopSWorkDirectory],
  Print["LoopSWorkDirectory was not created: ", LoopSWorkDirectory];
  Exit[1]
];

Print["LoopS headless load smoke test passed."];
Exit[0];
