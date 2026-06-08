ClearAll[NotebookDirectoryS];
NotebookDirectoryS[] := If[$FrontEnd === Null,
  Module[{cmd, script},
    cmd = Quiet@Check[$ScriptCommandLine, {}];
    script = If[ListQ[cmd] && Length[cmd] > 0, First[cmd], ""];
    If[StringQ[script] && FileExistsQ[script], DirectoryName[ExpandFileName[script]], Directory[]]
  ],
  Quiet@Check[DirectoryName[NotebookFileName[]], Directory[]]
]
