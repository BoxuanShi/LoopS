ClearAll[BladeWorkPath, BladeFamilyName, BladeRunDirectory];
BladeWorkPath[ProcessName_String] := FileNameJoin[{LoopSWorkDirectory, ProcessName, "IBPReduction" , "Blade"}];
BladeFamilyName[loops_List] := Module[{str}, str = StringJoin @@ Table["N", {i, Length@loops}]; "family" <> str <> "LO"]
BladeRunDirectory[workPath_String, familyName_String, problem_Integer] := FileNameJoin[{workPath, familyName <> ToString[problem]}]


ClearAll[BladePrepareIBP];Protect[BL];
BladePrepareIBP::usage = "BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]].
\"IBPKernels\": _Integer : LoopSParallelKernels : fThreads in config file.
\"BLnumeric\".
\"ExtraIntDerivDen\".
\"ExtraIntDerivPara\".
Depending options: {FindCompleteGList}";
Options[BladePrepareIBP] := CreateOptions[{"IBPKernels" :> LoopSParallelKernels, "BLnumeric" -> {}, "ExtraIntDerivDen" -> {}, "ExtraIntDerivPara" -> {}}, {FindCompleteGList}];
BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, BladePrepareIBP[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}, Evaluate@opt]]
BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]] := Module[{x, Fslist2, stream, templateS, rulesS, templateS2, toBLform, targets, topsector, runDirectory, familyName},
  (*check install*)
  If[
    If[$BladeInstallPath === "Blade`",
      Flatten[FileNames["Blade", #] & /@ $Path] === {},
      !FileExistsQ[$BladeInstallPath]],
    Print["Blade is not avaliable."]; Abort[]
  ];
  (*toBLform*)
  familyName = BladeFamilyName <> ToString[problem];
  runDirectory = BladeRunDirectory[BladeWorkPath, BladeFamilyName, problem];
  toBLform[expr_] := expr /. G[a_, b_] :> BL[familyName, b];
  (*create directories*)
  Off[CreateDirectory::eexist];
  CreateDirectoryS@runDirectory;
  CreateDirectoryS@FileNameJoin[{runDirectory, "temp"}];
  On[CreateDirectory::eexist];
  (*target file*)
  Fslist2 = DeleteCases[Fslist, x_ /; x[[1]] =!= problem];
  topsector = FindTopSectors@Fslist2 // toBLform;
  targets = FindCompleteGList[Fslist2, ReplacePart[ConstantArray[{}, problem], -1 -> familyi], loops, kinematics, Evaluate@FilterOptions[{opt}, FindCompleteGList]] // toBLform;
  Export[FileNameJoin[{runDirectory, familyName <> ".m"}], targets];
  (*save file*)
  templateS = BladeTemplate;
  rulesS = <|
    "Blade" -> ToStringInput@$BladeInstallPath,
    "threads" -> ToStringInput@OptionValue["IBPKernels"],
    "familyname" -> ToStringInput@familyName,
    "problem" -> ToStringInput@problem,
    "loop" -> ToStringInput@loops,
    "leg" -> ToStringInput@extmomsind,
    "kinematics" -> ToStringInput@kinematics,
    "family" -> ToStringInput@familyi,
    "topsector" -> ToStringInput@topsector,
    "targets" -> ToStringInput@(targets // toBLform),
    "numeric" -> ToStringInput@OptionValue["BLnumeric"],
    "save" -> ToStringInput@FileNameJoin[{runDirectory, familyName <> "save.m"}],
    "ExtraIntDerivDen" -> ToStringInput@OptionValue["ExtraIntDerivDen"],
    "ExtraIntDerivPara" -> ToStringInput@OptionValue["ExtraIntDerivPara"]
    |>;
  templateS2 = TemplateApply[templateS, rulesS];
  FileTemplateApply[templateS2, FileNameJoin[{runDirectory, "temp", familyName <> ".wl"}]];
  (*Run file*)
  stream = OpenWrite[FileNameJoin[{runDirectory, "BladeRun.txt"}]];
  WriteString[stream, StringRiffle[WolframScriptCommand[FileNameJoin[{runDirectory, "temp", familyName <> ".wl"}]], " "] <> ";\n"];
  Close[stream];
  ]


ClearAll[BladeRunIBP]
BladeRunIBP::usage = "BladeRunIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}, opt:OptionsPattern[]].";
BladeRunIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess, opt:OptionsPattern[]] := Module[{p=ReleaseHold@process}, BladeRunIBP[problem, loops, {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}, Evaluate@opt]]
BladeRunIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}, opt:OptionsPattern[]] := Module[{logsave, runDirectory, familyName, script},
  familyName = BladeFamilyName <> ToString[problem];
  runDirectory = BladeRunDirectory[BladeWorkPath, BladeFamilyName, problem];
  script = FileNameJoin[{runDirectory, "temp", familyName <> ".wl"}];
  (*save*)
  logsave = RunProcess[WolframScriptCommand[script], ProcessDirectory -> runDirectory]["StandardOutput"];
  Export[FileNameJoin[{runDirectory, "temp", familyName <> "save_log.txt"}], logsave, "Text"];
  ]


ClearAll[BladeLoadIBP]
BladeLoadIBP::usage = "BladeLoadIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}]";
BladeLoadIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, BladeLoadIBP[problem, loops, {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}]]
BladeLoadIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}] := Module[{path, legacyPath, familyName},
  familyName = BladeFamilyName <> ToString[problem];
  path = FileNameJoin[{BladeRunDirectory[BladeWorkPath, BladeFamilyName, problem], familyName <> "save.m"}];
  legacyPath = FileNameJoin[{BladeWorkPath, familyName <> "save.m"}];
  If[! FileExistsQ[path] && FileExistsQ[legacyPath], path = legacyPath];
  Get[path]
  ]


ClearAll[BladeIBPReduction]
BladeIBPReduction::usage = "BladeIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]].
Depending options: {BladePrepareIBP}";
Options[BladeIBPReduction] := CreateOptions[{}, {BladePrepareIBP}];
BladeIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, BladeIBPReduction[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}, Evaluate@opt]]
BladeIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]] := (
  BladePrepareIBP[Fslist, {familyi, problem}, loops, extmomsind, kinematics, {BladeWorkPath, BladeFamilyName}, Evaluate@FilterOptions[{opt}, BladePrepareIBP]];
  BladeRunIBP[problem, loops, {BladeWorkPath, BladeFamilyName}];
  BladeLoadIBP[problem, loops, {BladeWorkPath, BladeFamilyName}]
  )


ClearAll[BladeTemplate];
BladeTemplate = "
Get[`Blade`];
BLNthreads = `threads`;
family = ToExpression@`familyname`;
dimension = D;
loop = `loop`;
leg = `leg`;
conservation = {};
replacement = `kinematics`;
propagator = `family`;
topsector = `topsector` /. BL[a_, b_] :> BL[ToExpression@a, b];
numeric = `numeric`;
targets = `targets` /. BL[a_, b_] :> BL[ToExpression@a, b];
BLFamilyDefine[ToExpression@`familyname`,dimension,propagator,loop,leg,conservation,replacement,topsector,numeric,ExtraIntDerivDen->`ExtraIntDerivDen`,ExtraIntDerivPara->`ExtraIntDerivPara`];
Thread[targets->BLReduce[targets, ReadCacheQ -> False]] /. BL[a_, b_] :> G[`problem`, b] >> `save`;
"
