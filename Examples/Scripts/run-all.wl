scriptDir = DirectoryName[ExpandFileName[First[$ScriptCommandLine]]];
scripts = {"load-smoke.wl", "pion-emff.wl", "zhr.wl"};

Do[
  result = RunProcess[{"wolframscript", "-file", FileNameJoin[{scriptDir, script}]}, "ExitCode"];
  If[result =!= 0,
    Print[script, " failed with exit code ", result];
    Exit[result]
  ],
  {script, scripts}
];

Print["All LoopS script examples passed."];
Exit[0];
