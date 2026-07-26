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
  Length[DownValues[#]] > 0 & /@ {
    CreateProcess, AmplitudeReduce, GeneratePV, KiraIBPReduction,
    FIRERunDirectory, KiraRunDirectory, BladeRunDirectory, AMFlowRunDirectory
  },
  {True, True, True, True, True, True, True, True},
  TestID -> "core-symbols-loaded"
]

VerificationTest[
  {
    FIRERunDirectory["root", "familyNLO", 2],
    KiraRunDirectory["root", "familyNLO", 2],
    BladeRunDirectory["root", "familyNLO", 2],
    AMFlowRunDirectory["root", "AMFfamilyNLO", 2]
  },
  {
    FileNameJoin[{"root", "familyNLO2"}],
    FileNameJoin[{"root", "familyNLO2"}],
    FileNameJoin[{"root", "familyNLO2"}],
    FileNameJoin[{"root", "AMFfamilyNLOS2"}]
  },
  TestID -> "family-run-directories"
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
  ("KiraFermatExecutable" /. Options[#]) & /@
    {KiraRunIBP, KiraIBPReduction, KiraReduction},
  {Automatic, Automatic, Automatic},
  TestID -> "kira-fermat-executable-default-propagates"
]

VerificationTest[
  Sort[
    LoopS`Private`KiraSectorString /@
      FindTopSectors[{
        G[1, {1, 1, 0}],
        G[1, {1, 0, 1}],
        G[1, {1, 0, 0}],
        G[1, {2, 1, 0}]
      }][[All, 2]]
  ],
  {"b101", "b110"},
  TestID -> "kira-preserves-incomparable-top-sectors"
]

VerificationTest[
  Module[
    {testRoot, family, targets, prepared, integralFamiliesYaml, jobYaml, result},
    testRoot = FileNameJoin[{
      $TemporaryDirectory, "LoopS-kira-sector-" <> CreateUUID[]
    }];
    family = {
      (l2 n)/2 + (l2 nb)/2,
      -l1 n + nq - w1,
      -l1 nb - l2 nb + w2,
      -l1 nb - nbk + w2,
      l1^2,
      l2^2,
      (l1 + l2)^2
    };
    targets = {
      G[152, {1, 1, 1, -1, 1, 1, 0}],
      G[152, {1, 1, 1, 0, 1, 1, 0}]
    };
    result = Quiet@Check[
      prepared = KiraPrepareIBP[
        targets, {family, 152}, {l1, l2}, {n, nb},
        {n^2 -> 0, nb^2 -> 0, n nb -> 2},
        {testRoot, "familyNNLO"},
        "KiraKinematicDimensions" -> {nq -> 1, nbk -> 1, w1 -> 1, w2 -> 1},
        "DropZeroSectorQ" -> False
      ];
      integralFamiliesYaml = Import[
        FileNameJoin[{
          prepared["RunDirectory"], "config", "integralfamilies.yaml"
        }],
        "Text"
      ];
      jobYaml = Import[
        FileNameJoin[{prepared["RunDirectory"], "job.yaml"}],
        "Text"
      ];
      {
        prepared["TopLevelSectors"],
        prepared["Bounds"],
        StringContainsQ[
          integralFamiliesYaml,
          "top_level_sectors: [\"b1110110\"]"
        ],
        StringContainsQ[
          jobYaml,
          "sectors: [\"b1110110\"], r: 6, s: 1"
        ],
        prepared["Bounds"]["r"] >=
          Max[StringCount[#, "1"] & /@ prepared["TopLevelSectors"]]
      },
      $Failed
    ];
    If[DirectoryQ[testRoot], DeleteDirectory[testRoot, DeleteContents -> True]];
    result
  ],
  {
    {"b1110110"},
    <|"r" -> 6, "s" -> 1|>,
    True,
    True,
    True
  },
  TestID -> "kira-top-sector-follows-targets"
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
