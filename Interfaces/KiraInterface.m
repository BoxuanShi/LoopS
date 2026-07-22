ClearAll[KiraWorkPath, KiraFamilyName, KiraRunDirectory];
KiraWorkPath[processName_String] := FileNameJoin[{LoopSWorkDirectory, processName, "IBPReduction", "Kira"}];
KiraFamilyName[loops_List] := "family" <> StringJoin @@ Table["N", {Length[loops]}] <> "LO";
KiraRunDirectory[workPath_String, familyName_String, problem_Integer] :=
  FileNameJoin[{workPath, familyName <> ToString[problem]}];

ClearAll[KiraExpressionString, KiraYamlQuote, KiraWriteInput, KiraScalarProductEntry,
  KiraDimension, KiraIntegralString, KiraIntegralToG, KiraFirstStringDifference];

KiraExpressionString[expr_] := ToString[expr, InputForm, PageWidth -> Infinity];
KiraYamlQuote[expr_] := Module[{text},
  text = If[StringQ[expr], expr, KiraExpressionString[expr]];
  "\"" <> StringReplace[text, {"\\" -> "\\\\", "\"" -> "\\\""}] <> "\""
];

KiraWriteInput[path_String, text_String] := Module[{existing},
  If[FileExistsQ[path],
    existing = Import[path, "Text"];
    If[Hash[StringTrim[existing], "SHA256"] =!= Hash[StringTrim[text], "SHA256"], Return[$Failed]],
    Export[path, text, "Text"]
  ];
  path
];

KiraFirstStringDifference[first_String, second_String] := Module[{limit, position},
  limit = Min[StringLength[first], StringLength[second]];
  position = FirstPosition[
    MapThread[UnsameQ, {Characters@StringTake[first, limit], Characters@StringTake[second, limit]}],
    True,
    Missing["NotFound"]
  ];
  If[MissingQ[position], If[StringLength[first] === StringLength[second], None, limit + 1], First[position]]
];

KiraScalarProductEntry[rule_Rule] := Module[{lhs, rhs, factors, momenta},
  {lhs, rhs} = List @@ rule;
  momenta = Which[
    MatchQ[lhs, Power[_, 2]], {First[lhs], First[lhs]},
    Head[lhs] === Times && Length[lhs] === 2, List @@ lhs,
    MatchQ[lhs, _[_, _]] && MemberQ[{"SP", "SPD"}, SymbolName[Head[lhs]]], List @@ lhs,
    MatchQ[lhs, Pair[Momentum[_, ___], Momentum[_, ___]]],
      lhs /. Pair[Momentum[a_, ___], Momentum[b_, ___]] :> {a, b},
    True, $Failed
  ];
  If[momenta === $Failed, $Failed, {momenta[[1]], momenta[[2]], rhs}]
];

KiraDimension[symbol_Symbol, specification_] := Module[{association},
  association = Which[
    specification === Automatic, <||>,
    AssociationQ[specification], specification,
    MatchQ[specification, {(_Rule | _RuleDelayed) ...}], Association[specification],
    True, <||>
  ];
  Lookup[association, symbol, Lookup[association, SymbolName[symbol], 0]]
];

KiraIntegralString[familyName_String, indices_List] :=
  familyName <> "[" <> StringRiffle[ToString[#, InputForm] & /@ indices, ","] <> "]";

KiraIntegralToG[expr_, familySymbol_Symbol, problem_Integer] :=
  MapAll[If[Head[#] === familySymbol, G[problem, List @@ #], #] &, expr];

ClearAll[KiraPrepareIBP];
KiraPrepareIBP::usage = "KiraPrepareIBP prepares an isolated Kira project for one LoopS integral family. The default integral_ordering is 2, which prefers positive propagator powers over irreducible scalar-product numerators.";
KiraPrepareIBP::targets = "No G integrals for problem `1` were supplied.";
KiraPrepareIBP::indices = "Kira targets for problem `1` do not all have the expected G[problem, indices_List] form.";
KiraPrepareIBP::kinematics = "Kinematics rule `1` cannot be represented as a Kira scalar-product rule.";
KiraPrepareIBP::dimension = "Kinematic dimension `1` for invariant `2` must be an integer.";
KiraPrepareIBP::ordering = "Kira integral ordering `1` must be an integer from 1 through 8.";
KiraPrepareIBP::state = "Refusing to overwrite Kira input `1` because it differs at character `2` from the existing isolated run. Existing: `3`; proposed: `4`. Use a new Kira work path or remove that run explicitly.";

Options[KiraPrepareIBP] := CreateOptions[{
  "KiraIntegralOrdering" -> 2,
  "KiraKinematicDimensions" -> Automatic,
  "KiraPreferredMasters" -> Automatic
}, {FindCompleteGList}];

KiraPrepareIBP[
  Fslist_List,
  {familyi_List, problem_Integer},
  loops_List,
  process_Association : Hold@CurrentProcess,
  opt : OptionsPattern[]
] := Module[{p = ReleaseHold@process},
  KiraPrepareIBP[
    Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"],
    {KiraWorkPath[p["ProcessName"]], KiraFamilyName[loops]}, Evaluate@opt
  ]
];

KiraPrepareIBP[
  Fslist_List,
  {familyi_List, problem_Integer},
  loops_List,
  extmomsind_List,
  kinematics_List,
  {workPath_String, familyName_String},
  opt : OptionsPattern[]
] := Module[
  {targets, completeTargets, indices, topologyName, runDirectory, configDirectory,
   ordering, preferredMasters, dimensions, symbols, invariants, invariantLines,
   scalarEntries, scalarLines, propagatorLines, topSector, maxR, maxS,
   integralFamiliesYaml, kinematicsYaml, jobYaml, targetText, loopSTargetText,
   preferredText, preferredLine, inputFiles, result, existing, differencePosition},

  ordering = OptionValue["KiraIntegralOrdering"];
  If[! IntegerQ[ordering] || ! Between[ordering, {1, 8}],
    Message[KiraPrepareIBP::ordering, ordering]; Return[$Failed]
  ];

  targets = Select[Fslist, MatchQ[#, _G] && First[#] === problem &];
  If[targets === {}, Message[KiraPrepareIBP::targets, problem]; Return[$Failed]];

  completeTargets = FindCompleteGList[
    targets,
    ReplacePart[ConstantArray[{}, problem], problem -> familyi],
    loops,
    kinematics,
    Evaluate@FilterOptions[{opt}, FindCompleteGList]
  ];
  If[! VectorQ[completeTargets, MatchQ[#, G[problem, _List]] &],
    Message[KiraPrepareIBP::indices, problem]; Return[$Failed]
  ];
  completeTargets = DeleteDuplicates[completeTargets];
  indices = completeTargets[[All, 2]];

  topologyName = familyName <> ToString[problem];
  runDirectory = KiraRunDirectory[workPath, familyName, problem];
  configDirectory = FileNameJoin[{runDirectory, "config"}];
  If[! DirectoryQ[configDirectory],
    CreateDirectory[configDirectory, CreateIntermediateDirectories -> True]
  ];

  topSector = "b" <> StringRepeat["1", Length[familyi]];
  maxR = Max[Total[Map[Max[#, 0] &, #]] & /@ indices];
  maxS = Max[Total[Map[-Min[#, 0] &, #]] & /@ indices];

  symbols = DeleteDuplicates@Cases[
    {familyi, Last /@ kinematics},
    symbol_Symbol /; Context[symbol] === "Global`",
    Infinity
  ];
  invariants = Complement[symbols, Join[loops, extmomsind, {d, D}]];
  dimensions = OptionValue["KiraKinematicDimensions"];
  If[AnyTrue[invariants, ! IntegerQ[KiraDimension[#, dimensions]] &],
    result = SelectFirst[invariants, ! IntegerQ[KiraDimension[#, dimensions]] &];
    Message[KiraPrepareIBP::dimension, KiraDimension[result, dimensions], result];
    Return[$Failed]
  ];
  invariantLines = ("    - [" <> SymbolName[#] <> ", " <>
      ToString[KiraDimension[#, dimensions]] <> "]") & /@ invariants;

  scalarEntries = KiraScalarProductEntry /@ kinematics;
  If[MemberQ[scalarEntries, $Failed],
    result = First@Pick[kinematics, scalarEntries, $Failed];
    Message[KiraPrepareIBP::kinematics, HoldForm[result]];
    Return[$Failed]
  ];
  scalarLines = ("    - [[" <> KiraExpressionString[#[[1]]] <> "," <>
      KiraExpressionString[#[[2]]] <> "], " <> KiraExpressionString[#[[3]]] <> "]") & /@
    scalarEntries;

  propagatorLines = ("      - [ " <> KiraYamlQuote[#] <> ", 0 ]") & /@ familyi;
  integralFamiliesYaml = StringJoin[
    "integralfamilies:\n",
    "  - name: ", KiraYamlQuote[topologyName], "\n",
    "    loop_momenta: [", StringRiffle[KiraExpressionString /@ loops, ","], "]\n",
    "    top_level_sectors: [", KiraYamlQuote[topSector], "]\n",
    "    propagators:\n", StringRiffle[propagatorLines, "\n"], "\n"
  ];

  kinematicsYaml = StringJoin[
    "kinematics:\n",
    "  incoming_momenta: [", StringRiffle[KiraExpressionString /@ extmomsind, ","], "]\n",
    "  outgoing_momenta: []\n",
    "  momentum_conservation: []\n",
    If[invariantLines === {}, "  kinematic_invariants: []\n",
      "  kinematic_invariants:\n" <> StringRiffle[invariantLines, "\n"] <> "\n"],
    If[scalarLines === {}, "  scalarproduct_rules: []\n",
      "  scalarproduct_rules:\n" <> StringRiffle[scalarLines, "\n"] <> "\n"]
  ];

  targetText = StringRiffle[KiraIntegralString[topologyName, #] & /@ indices, "\n"] <> "\n";
  loopSTargetText = KiraExpressionString[completeTargets] <> "\n";

  preferredMasters = OptionValue["KiraPreferredMasters"];
  preferredLine = "";
  preferredText = "";
  If[preferredMasters =!= Automatic,
    If[! ListQ[preferredMasters] || ! VectorQ[preferredMasters, MatchQ[#, G[problem, _List]] &],
      Message[KiraPrepareIBP::indices, problem]; Return[$Failed]
    ];
    preferredText = StringRiffle[
      KiraIntegralString[topologyName, #[[2]]] & /@ preferredMasters,
      "\n"
    ] <> "\n";
    preferredLine = "      preferred_masters: \"preferred_masters\"\n";
  ];

  jobYaml = StringJoin[
    "jobs:\n",
    "  - reduce_sectors:\n",
    "      reduce:\n",
    "        - {topologies: [", topologyName, "], sectors: [", KiraYamlQuote[topSector],
      "], r: ", ToString[maxR], ", s: ", ToString[maxS], "}\n",
    "      select_integrals:\n",
    "        select_mandatory_list:\n",
    "          - [", KiraYamlQuote[topologyName], ", \"targets\"]\n",
    "      run_symmetries: true\n",
    "      run_initiate: true\n",
    "      run_triangular: true\n",
    "      run_back_substitution: true\n",
    preferredLine,
    "      integral_ordering: ", ToString[ordering], "\n",
    "  - kira2math:\n",
    "      target:\n",
    "        - [", KiraYamlQuote[topologyName], ", \"targets\"]\n"
  ];

  inputFiles = {
    {FileNameJoin[{configDirectory, "integralfamilies.yaml"}], integralFamiliesYaml},
    {FileNameJoin[{configDirectory, "kinematics.yaml"}], kinematicsYaml},
    {FileNameJoin[{runDirectory, "job.yaml"}], jobYaml},
    {FileNameJoin[{runDirectory, "targets"}], targetText},
    {FileNameJoin[{runDirectory, "LoopS-targets.m"}], loopSTargetText}
  };
  If[preferredMasters =!= Automatic,
    inputFiles = Append[inputFiles, {FileNameJoin[{runDirectory, "preferred_masters"}], preferredText}]
  ];

  result = SelectFirst[inputFiles, KiraWriteInput @@ # === $Failed &, Missing["NotFound"]];
  If[! MissingQ[result],
    existing = Import[First[result], "Text"];
    differencePosition = KiraFirstStringDifference[existing, Last[result]];
    Message[
      KiraPrepareIBP::state,
      First[result],
      differencePosition,
      StringTake[existing, {Max[1, differencePosition - 30], Min[StringLength[existing], differencePosition + 30]}],
      StringTake[Last[result], {Max[1, differencePosition - 30], Min[StringLength[Last[result]], differencePosition + 30]}]
    ];
    Return[$Failed]
  ];

  <|
    "RunDirectory" -> runDirectory,
    "Topology" -> topologyName,
    "Targets" -> completeTargets,
    "IntegralOrdering" -> ordering,
    "Bounds" -> <|"r" -> maxR, "s" -> maxS|>
  |>
];

ClearAll[KiraRunIBP];
KiraRunIBP::usage = "KiraRunIBP runs a prepared Kira family project. Its internal worker count defaults to LoopSParallelKernels, matching the FIRE interface.";
KiraRunIBP::executable = "Kira executable `1` could not be started.";
KiraRunIBP::version = "Kira version check failed: `1`.";
KiraRunIBP::failed = "Kira exited with status `1`. See `2`.";
KiraRunIBP::missing = "Prepared Kira job `1` does not exist.";
KiraRunIBP::parallel = "Kira parallelism `1` must be a positive integer.";

Options[KiraRunIBP] = {
  "KiraExecutable" :> $KiraExecutable,
  "KiraParallel" :> LoopSParallelKernels
};

KiraRunIBP[
  problem_Integer,
  loops_List,
  process_Association : Hold@CurrentProcess,
  opt : OptionsPattern[]
] := Module[{p = ReleaseHold@process},
  KiraRunIBP[
    problem, loops, {KiraWorkPath[p["ProcessName"]], KiraFamilyName[loops]},
    Evaluate@opt
  ]
];

KiraRunIBP[
  problem_Integer,
  loops_List,
  {workPath_String, familyName_String},
  opt : OptionsPattern[]
] := Module[{runDirectory, jobFile, executable, parallel, versionResult, result, logFile, command},
  runDirectory = KiraRunDirectory[workPath, familyName, problem];
  jobFile = FileNameJoin[{runDirectory, "job.yaml"}];
  If[! FileExistsQ[jobFile], Message[KiraRunIBP::missing, jobFile]; Return[$Failed]];

  executable = OptionValue["KiraExecutable"];
  parallel = OptionValue["KiraParallel"];
  If[! IntegerQ[parallel] || parallel < 1,
    Message[KiraRunIBP::parallel, parallel]; Return[$Failed]
  ];
  If[! StringQ[executable], Message[KiraRunIBP::executable, executable]; Return[$Failed]];

  versionResult = Quiet@Check[
    RunProcess[{executable, "--version"}, ProcessDirectory -> runDirectory],
    $Failed
  ];
  If[versionResult === $Failed,
    Message[KiraRunIBP::executable, executable]; Return[$Failed]
  ];
  If[versionResult["ExitCode"] =!= 0 ||
      ! StringContainsQ[versionResult["StandardOutput"] <> versionResult["StandardError"], "Kira version"],
    Message[KiraRunIBP::version,
      StringTrim[versionResult["StandardOutput"] <> versionResult["StandardError"]]];
    Return[$Failed]
  ];

  command = {executable, "job.yaml", "--parallel=" <> ToString[parallel]};
  result = RunProcess[command, ProcessDirectory -> runDirectory];
  logFile = FileNameJoin[{runDirectory, "LoopS-kira.log"}];
  Export[
    logFile,
    StringJoin[
      "Executable: ", executable, "\n",
      "Version: ", StringTrim[versionResult["StandardOutput"] <> versionResult["StandardError"]], "\n",
      "Working directory: ", runDirectory, "\n",
      "Command: ", StringRiffle[command, " "], "\n\n",
      result["StandardOutput"],
      If[result["StandardError"] === "", "", "\nSTDERR:\n" <> result["StandardError"]]
    ],
    "Text"
  ];
  If[result["ExitCode"] =!= 0,
    Message[KiraRunIBP::failed, result["ExitCode"], logFile]; Return[$Failed]
  ];
  <|
    "ExitCode" -> result["ExitCode"],
    "Version" -> StringTrim[versionResult["StandardOutput"] <> versionResult["StandardError"]],
    "RunDirectory" -> runDirectory,
    "LogFile" -> logFile
  |>
];

ClearAll[KiraLoadIBP];
KiraLoadIBP::usage = "KiraLoadIBP imports Kira's Mathematica rules and adds identity rules for requested targets that are master integrals.";
KiraLoadIBP::missing = "Required Kira result file `1` does not exist.";
KiraLoadIBP::unreduced = "Kira did not reduce `1` requested non-master integrals: `2`.";
KiraLoadIBP::format = "Kira result `1` is not a list of rules.";

KiraLoadIBP[
  problem_Integer,
  loops_List,
  process_Association : Hold@CurrentProcess
] := Module[{p = ReleaseHold@process},
  KiraLoadIBP[problem, loops, {KiraWorkPath[p["ProcessName"]], KiraFamilyName[loops]}]
];

KiraLoadIBP[
  problem_Integer,
  loops_List,
  {workPath_String, familyName_String}
] := Module[
  {runDirectory, topologyName, reductionFile, mastersFile, targetsFile, rawRules,
   masterLines, masterStrings, familySymbol, rules, masters, targets, missing,
   nonMasterMissing},
  topologyName = familyName <> ToString[problem];
  runDirectory = KiraRunDirectory[workPath, familyName, problem];
  reductionFile = FileNameJoin[{runDirectory, "results", topologyName, "kira_targets.m"}];
  mastersFile = FileNameJoin[{runDirectory, "results", topologyName, "masters.final"}];
  targetsFile = FileNameJoin[{runDirectory, "LoopS-targets.m"}];
  Do[
    If[! FileExistsQ[path], Message[KiraLoadIBP::missing, path]; Return[$Failed]],
    {path, {reductionFile, mastersFile, targetsFile}}
  ];

  rawRules = Get[reductionFile];
  If[! MatchQ[rawRules, {(_Rule | _RuleDelayed) ...}],
    Message[KiraLoadIBP::format, reductionFile]; Return[$Failed]
  ];
  familySymbol = Symbol["Global`" <> topologyName];
  rules = KiraIntegralToG[rawRules, familySymbol, problem] /. d -> D;
  targets = Get[targetsFile];

  masterLines = Import[mastersFile, "Lines"];
  masterStrings = DeleteCases[
    StringTrim[First[StringSplit[#, "#"]]] & /@ masterLines,
    ""
  ];
  masters = KiraIntegralToG[ToExpression /@ masterStrings, familySymbol, problem] /. d -> D;

  missing = Complement[targets, If[rules === {}, {}, First /@ rules]];
  nonMasterMissing = Complement[missing, masters];
  If[nonMasterMissing =!= {},
    Message[KiraLoadIBP::unreduced, Length[nonMasterMissing], nonMasterMissing];
    Return[$Failed]
  ];
  Join[rules, Thread[missing -> missing]]
];

ClearAll[KiraIBPReduction];
KiraIBPReduction::usage = "KiraIBPReduction prepares, runs, and imports a Kira reduction for one LoopS integral family.";
Options[KiraIBPReduction] := CreateOptions[{}, {KiraPrepareIBP, KiraRunIBP}];

KiraIBPReduction[
  Fslist_List,
  {familyi_List, problem_Integer},
  loops_List,
  process_Association : Hold@CurrentProcess,
  opt : OptionsPattern[]
] := Module[{p = ReleaseHold@process},
  KiraIBPReduction[
    Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"],
    {KiraWorkPath[p["ProcessName"]], KiraFamilyName[loops]}, Evaluate@opt
  ]
];

KiraIBPReduction[
  Fslist_List,
  {familyi_List, problem_Integer},
  loops_List,
  extmomsind_List,
  kinematics_List,
  {workPath_String, familyName_String},
  opt : OptionsPattern[]
] := Module[{prepared, run},
  prepared = KiraPrepareIBP[
    Fslist, {familyi, problem}, loops, extmomsind, kinematics,
    {workPath, familyName}, Evaluate@FilterOptions[{opt}, KiraPrepareIBP]
  ];
  If[prepared === $Failed, Return[$Failed]];
  run = KiraRunIBP[
    problem, loops, {workPath, familyName}, Evaluate@FilterOptions[{opt}, KiraRunIBP]
  ];
  If[run === $Failed, Return[$Failed]];
  KiraLoadIBP[problem, loops, {workPath, familyName}]
];

ClearAll[KiraReduction];
KiraReduction::usage = "KiraReduction reduces all classified families with Kira and merges the resulting rules into the original LoopS family basis.";
Options[KiraReduction] := CreateOptions[{}, {KiraIBPReduction, FamilyMerge, TableS}];

KiraReduction[
  Fslist_List,
  loops_List,
  family_List,
  process_Association : Hold@CurrentProcess,
  opt : OptionsPattern[]
] := Module[{p = ReleaseHold@process},
  KiraReduction[
    Fslist, loops, family, p["extmomsind"], p["kinematics"],
    {KiraWorkPath[p["ProcessName"]], KiraFamilyName[loops]}, Evaluate@opt
  ]
];

KiraReduction[
  Fslist_List,
  loops_List,
  family_List,
  extmomsind_List,
  kinematics_List,
  {workPath_String, familyName_String},
  opt : OptionsPattern[]
] := Module[{ibps},
  ibps = TableS[
    KiraIBPReduction[
      Fslist, {family[[i]], i}, loops, extmomsind, kinematics,
      {workPath, familyName}, Evaluate@FilterOptions[{opt}, KiraIBPReduction]
    ],
    {i, Length[family]},
    Evaluate@FilterOptions[{opt}, TableS]
  ];
  If[MemberQ[ibps, $Failed], Return[$Failed]];
  FamilyMerge[
    Fslist, family, ibps, loops, extmomsind, kinematics,
    Evaluate@FilterOptions[{opt}, FamilyMerge]
  ]
];
