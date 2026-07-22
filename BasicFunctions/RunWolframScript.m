ClearAll[WolframKernelExecutable, WolframScriptCommand];

WolframKernelExecutable[] := Module[{commandLine, candidates},
  commandLine = Quiet@Check[$CommandLine, {}];
  candidates = DeleteDuplicates@Select[
    Flatten@{
      If[ListQ[commandLine] && Length[commandLine] > 0, First[commandLine], Nothing],
      FileNameJoin[{$InstallationDirectory, "MacOS", "WolframKernel"}],
      FileNameJoin[{$InstallationDirectory, "WolframKernel.exe"}],
      FileNameJoin[{$InstallationDirectory, "Executables", "WolframKernel"}],
      FileNameJoin[{$InstallationDirectory, "Executables", "wolfram"}]
    },
    StringQ
  ];
  SelectFirst[candidates, FileExistsQ, Missing["NotFound"]]
];

WolframScriptCommand[file_String] := Module[{kernel, expandedFile},
  kernel = WolframKernelExecutable[];
  expandedFile = ExpandFileName[file];
  If[
    MissingQ[kernel],
    {"wolframscript", "-file", expandedFile},
    {kernel, "-noprompt", "-script", expandedFile}
  ]
];
