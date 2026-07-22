VerificationTest[
  FileNameSplit[ExpandFileName[$LoopSInstallPath]],
  FileNameSplit[projectRoot],
  TestID -> "install-path"
]

VerificationTest[
  FileNameSplit[ExpandFileName[$LoopSBaseDirectory[]]],
  FileNameSplit[testsDirectory],
  TestID -> "headless-base-directory"
]

VerificationTest[
  FileNameSplit[ExpandFileName[NotebookDirectoryS[]]],
  FileNameSplit[testsDirectory],
  TestID -> "notebook-directory-helper"
]

VerificationTest[
  FileNameSplit[ExpandFileName[LoopSWorkDirectory]],
  FileNameSplit[ExpandFileName[FileNameJoin[{testsDirectory, "LoopSFile", "Processes"}]]],
  TestID -> "headless-work-directory"
]

VerificationTest[
  DirectoryQ[LoopSWorkDirectory],
  True,
  TestID -> "work-directory-created"
]

VerificationTest[
  StringMatchQ[$LoopSVersion, DigitCharacter .. ~~ "." ~~ DigitCharacter .. ~~ "." ~~ DigitCharacter ..],
  True,
  TestID -> "version-format"
]

VerificationTest[
  Get[FileNameJoin[{projectRoot, "PacletInfo.wl"}]]["Version"],
  $LoopSVersion,
  TestID -> "paclet-version-matches-package"
]

VerificationTest[
  Length[DownValues[#]] > 0 & /@ {CreateProcess, AmplitudeReduce, GeneratePV, KiraIBPReduction},
  {True, True, True, True},
  TestID -> "core-symbols-loaded"
]

VerificationTest[
  "KiraIntegralOrdering" /. Options[KiraPrepareIBP],
  2,
  TestID -> "kira-positive-power-ordering-default"
]

VerificationTest[
  "KiraParallel" /. Options[KiraRunIBP],
  LoopSParallelKernels,
  TestID -> "kira-parallel-default-matches-fire"
]

VerificationTest[
  MatchQ[LoopS`Private`WolframScriptCommand[FileNameJoin[{testsDirectory, "run-tests.wl"}]], {_String ..}],
  True,
  TestID -> "native-kernel-script-command"
]

VerificationTest[
  Module[{monitorEvaluated = False},
    {LoopS`Private`MonitorS[2 + 2, monitorEvaluated = True], monitorEvaluated}
  ],
  {4, False},
  TestID -> "headless-monitor-disabled"
]

VerificationTest[
  TableS[i^2, {i, 3}],
  {1, 4, 9},
  TestID -> "headless-table-without-front-end"
]

VerificationTest[
  sameSetQ[{a, b, c}, {c, a, b}],
  True,
  TestID -> "same-set-order-independent"
]

VerificationTest[
  ListS[2 + x + y, {x}],
  {2 + y, x},
  TestID -> "list-terms-by-variable"
]

VerificationTest[
  CoefficientS[a x + b y + c, {x, y}],
  {a, b, c},
  TestID -> "coefficient-with-remainder"
]

VerificationTest[
  SeparatePoly[2 + 3 x + 4 x y, {x, y}],
  {{2, 3, 4}, {1, x, x y}},
  TestID -> "separate-polynomial"
]

VerificationTest[
  ToStringNoContext[Symbol["LoopSTestContext`x"], InputForm],
  "x",
  TestID -> "string-without-context"
]
