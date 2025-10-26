ClearAll[BladeWorkPath, BladeFamilyName];
BladeWorkPath[ProcessName_String] := FileNameJoin[{LoopSWorkDirectory, ProcessName, "IBPReduction" , "Blade"}];
BladeFamilyName[loops_List] := Module[{str}, str = StringJoin @@ Table["N", {i, Length@loops}]; "family" <> str <> "LO"]


ClearAll[BladePrepareIBP];Protect[BL];
BladePrepareIBP::usage = "BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]].
\"IBPKernels\": _Integer : LoopSParallelKernels : fThreads in config file.
\"BLnumeric\".
\"ExtraIntDerivDen\".
\"ExtraIntDerivPara\".
Depending options: {FindCompleteGList}";
Options[BladePrepareIBP] := CreateOptions[{"IBPKernels" :> LoopSParallelKernels, "BLnumeric" -> {}, "ExtraIntDerivDen" -> {}, "ExtraIntDerivPara" -> {}}, {FindCompleteGList}];
BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, BladePrepareIBP[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}, Evaluate@opt]]
BladePrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {BladeWorkPath_String, BladeFamilyName_String}, opt : OptionsPattern[]] := Module[{i, x, Fslist2, FlistFamily, stream, templateS, rulesS, templateS2, toBLform, targets, topsector},
  (*check install*)
  If[
    If[$BladeInstallPath === "Blade`",
      Flatten[FileNames["Blade", #] & /@ $Path] === {},
      !FileExistsQ[$BladeInstallPath]],
    Print["Blade is not avaliable."]; Abort[]
  ];
  (*toBLform*)
  toBLform[expr_] := expr /. G[a_, b_] :> BL[BladeFamilyName <> ToString[problem], b];
  (*create directories*)
  Off[CreateDirectory::eexist];
  CreateDirectoryS@BladeWorkPath;
  CreateDirectoryS@FileNameJoin[{BladeWorkPath, "temp"}];
  On[CreateDirectory::eexist];
  (*target file*)
  Fslist2 = DeleteCases[Fslist, x_ /; x[[1]] =!= problem];
  topsector = FindTopSectors@Fslist2 // toBLform;
  targets = FindCompleteGList[Fslist2, ReplacePart[ConstantArray[{}, problem], -1 -> familyi], loops, kinematics, Evaluate@FilterOptions[{opt}, FindCompleteGList]] // toBLform;
  Export[FileNameJoin[{BladeWorkPath, BladeFamilyName <> ToString[problem] <> ".m"}], targets];
  (*save file*)
  templateS = BladeTemplate;
  rulesS = <|
    "Blade" -> ToStringInput@$BladeInstallPath,
    "threads" -> ToStringInput@OptionValue["IBPKernels"],
    "familyname" -> ToStringInput@(BladeFamilyName <> ToString[problem]),
    "problem" -> ToStringInput@problem,
    "loop" -> ToStringInput@loops,
    "leg" -> ToStringInput@extmomsind,
    "kinematics" -> ToStringInput@kinematics,
    "family" -> ToStringInput@familyi,
    "topsector" -> ToStringInput@topsector,
    "targets" -> ToStringInput@(targets // toBLform),
    "numeric" -> ToStringInput@OptionValue["BLnumeric"],
    "save" -> ToStringInput@FileNameJoin[{BladeWorkPath, BladeFamilyName <> ToString[problem] <> "save.m"}],
    "ExtraIntDerivDen" -> ToStringInput@OptionValue["ExtraIntDerivDen"],
    "ExtraIntDerivPara" -> ToStringInput@OptionValue["ExtraIntDerivPara"]
    |>;
  templateS2 = TemplateApply[templateS, rulesS];
  FileTemplateApply[templateS2, FileNameJoin[{BladeWorkPath, "temp", BladeFamilyName <> ToString[problem] <> ".wl"}]];
  (*Run file*)
  stream = OpenWrite[FileNameJoin[{BladeWorkPath, "BladeRun" <> ToString[Length@loops] <> ".txt"}]];
  Do[
    If[FileExistsQ[FileNameJoin[{BladeWorkPath, "temp", BladeFamilyName <> ToString[i] <> ".wl"}]], 
      WriteString[stream, "wolframscript -file " <> FileNameJoin[{BladeWorkPath, "temp", BladeFamilyName <> ToString[i] <> ".wl"}] <> ";\n"],
      Break[]]
    , {i, Infinity}];
  Close[stream];
  ]


ClearAll[BladeRunIBP]
BladeRunIBP::usage = "BladeRunIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}, opt:OptionsPattern[]].";
BladeRunIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess, opt:OptionsPattern[]] := Module[{p=ReleaseHold@process}, BladeRunIBP[problem, loops, {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}, Evaluate@opt]]
BladeRunIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}, opt:OptionsPattern[]] := Module[{logsave},
  (*save*)
  logsave = RunProcess[{"wolframscript", "-file", FileNameJoin[{BladeWorkPath, "temp", BladeFamilyName <> ToString[problem] <> ".wl"}]}]["StandardOutput"];
  Export[FileNameJoin[{BladeWorkPath, "temp", BladeFamilyName <> ToString[problem] <> "save_log.txt"}], logsave, "Text"];
  ]


ClearAll[BladeLoadIBP]
BladeLoadIBP::usage = "BladeLoadIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}]";
BladeLoadIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, BladeLoadIBP[problem, loops, {BladeWorkPath[p["ProcessName"]], BladeFamilyName[loops]}]]
BladeLoadIBP[problem_Integer, loops_List, {BladeWorkPath_String, BladeFamilyName_String}] := Module[{path},
  path = FileNameJoin[{BladeWorkPath, BladeFamilyName <> ToString[problem] <> "save.m"}];
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