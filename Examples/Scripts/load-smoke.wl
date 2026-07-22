scriptDir = DirectoryName[ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
]];
projectRoot = ParentDirectory[ParentDirectory[scriptDir]];
Get[FileNameJoin[{projectRoot, "LoopS.m"}]];

expectedRoot = ExpandFileName[projectRoot];
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

expectedWorkDirectory = PathName[FileNameJoin[{scriptDir, "LoopSFile", "Processes"}]];
If[FileNameSplit[ExpandFileName[LoopSWorkDirectory]] =!= FileNameSplit[ExpandFileName[expectedWorkDirectory]],
  Print["Unexpected LoopSWorkDirectory: ", LoopSWorkDirectory];
  Exit[1]
];

Print["LoopS headless load smoke test passed."];
Exit[0];
