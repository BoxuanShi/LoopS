scriptPath = ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
];
scriptDir = DirectoryName[scriptPath];
scripts = {"load-smoke.wl", "pion-emff.wl", "zhr.wl"};

kernel = SelectFirst[
  DeleteDuplicates@Select[
    {
      If[ListQ[$CommandLine] && Length[$CommandLine] > 0, First[$CommandLine], ""],
      FileNameJoin[{$InstallationDirectory, "MacOS", "WolframKernel"}],
      FileNameJoin[{$InstallationDirectory, "WolframKernel.exe"}],
      FileNameJoin[{$InstallationDirectory, "Executables", "WolframKernel"}],
      FileNameJoin[{$InstallationDirectory, "Executables", "wolfram"}]
    },
    StringQ
  ],
  FileExistsQ,
  Missing["NotFound"]
];
scriptCommand[file_] := If[
  MissingQ[kernel],
  {"wolframscript", "-file", file},
  {kernel, "-noprompt", "-script", file}
];

Do[
  result = RunProcess[scriptCommand[FileNameJoin[{scriptDir, script}]]];
  If[result["ExitCode"] =!= 0,
    If[result["StandardOutput"] =!= "", WriteString[$Output, result["StandardOutput"]]];
    If[result["StandardError"] =!= "", WriteString[$Output, result["StandardError"]]];
    Print[script, " failed with exit code ", result["ExitCode"]];
    Exit[result["ExitCode"]]
  ],
  {script, scripts}
];

Print["All LoopS script examples passed."];
Exit[0];
