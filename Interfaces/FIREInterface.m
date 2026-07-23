ClearAll[FIREWorkPath, FIREFamilyName, FIRERunDirectory];
FIREWorkPath[ProcessName_String] := FileNameJoin[{LoopSWorkDirectory, ProcessName, "IBPReduction" , "FIRE"}];
FIREFamilyName[loops_List] := Module[{str}, str = StringJoin @@ Table["N", {i, Length@loops}]; "family" <> str <> "LO"]
FIRERunDirectory[workPath_String, familyName_String, problem_Integer] := FileNameJoin[{workPath, familyName <> ToString[problem]}]


ClearAll[FIREPrepareIBP];
FIREPrepareIBP::usage = "FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]].
\"FIREcompressor\": _ : \"none\" : compressor in config file.
\"IBPKernels\": _Integer : LoopSParallelKernels : fThreads in config file.
\"FIREUseMMA\": (True|False) : False : use Mathematica or CXX to perform reduction.
Depending options: {FindCompleteGList}";
Options[FIREPrepareIBP] := CreateOptions[{"FIREcompressor" -> "none", "IBPKernels" :> LoopSParallelKernels, "FIREUseMMA" -> False}, {FindCompleteGList}];
FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIREPrepareIBP[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]]
FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]] := Module[{x, Fslist2, FlistFamily, stream, startfile, template, rules, template2, startscript, templateC, rulesC, templateC2, templateS, rulesS, templateS2, log, runDirectory, familyName},
  (*check install*)
  If[!FileExistsQ[$FIREInstallPath] || !StringMatchQ[FileNameTake@$FIREInstallPath, "FIRE" ~~ __ ~~ ".m"], Print["$FIREInstallPath is wrong."]; Abort[]];
  familyName = FIREFamilyName <> ToString[problem];
  runDirectory = FIRERunDirectory[FIREWorkPath, FIREFamilyName, problem];
  (*create directories*)
  Off[CreateDirectory::eexist];
  CreateDirectoryS@runDirectory;
  CreateDirectoryS@FileNameJoin[{runDirectory, "temp"}];
  On[CreateDirectory::eexist];
  (*start file*)
  template = FIRETemplate["Start"];
  startfile = FileNameJoin[{runDirectory, familyName}];
  rules = <|
    "FIRE" -> ToStringInput@$FIREInstallPath,
    "Internal" -> ToStringInput@loops,
    "External" -> ToStringInput@extmomsind,
    "Propagators" -> ToStringInput@familyi,
    "Replacements" -> ToStringInput@kinematics,
    "family" -> ToStringInput@startfile
    |>;
  template2 = TemplateApply[template, rules];
  startscript = FileNameJoin[{runDirectory, "temp", familyName <> "start.wl"}];
  (* If[FileExistsQ[startfile <> ".start"] && Quiet[ToExpression[Import[startscript, "Text"], InputForm, Hold] === ToExpression[template2, InputForm, Hold]], *)
  If[FileExistsQ[startfile <> ".start"] && ToExpression[Import[startscript, "Text"], InputForm, Hold] === ToExpression[template2, InputForm, Hold],
      Nothing,
      Off[DeleteFile::fdnfnd];
      DeleteFile[FileNameJoin[{runDirectory, familyName <> ".start"}]];
      DeleteFile[FileNameJoin[{runDirectory, "temp", familyName <> "start_log.txt"}]];
      On[DeleteFile::fdnfnd];
      FileTemplateApply[template2, startscript];
      log = RunProcess[WolframScriptCommand[startscript], ProcessDirectory -> runDirectory]["StandardOutput"];
      Export[FileNameJoin[{runDirectory, "temp", familyName <> "start_log.txt"}], log, "Text"];
    ];
  (*target file*)
  Fslist2 = DeleteCases[Fslist, x_ /; x[[1]] =!= problem];
  FlistFamily = FindCompleteGList[Fslist2, ReplacePart[ConstantArray[{}, problem], -1 -> familyi], loops, kinematics, Evaluate@FilterOptions[{opt}, FindCompleteGList]];
  FlistFamily = FlistFamily /. G -> List;
  Export[FileNameJoin[{runDirectory, familyName <> ".m"}], FlistFamily];
  (*config file*)
  templateC = FIRETemplate["Config"];
  rulesC = <|
    "compressor" -> OptionValue["FIREcompressor"],
    "fThreads" -> OptionValue["IBPKernels"],
    "tThreads" -> Ceiling[OptionValue["IBPKernels"]],
    "sThreads" -> Ceiling[OptionValue["IBPKernels"]],
    "variables" -> (ToString[Complement[Variables[{familyi, kinematics[[All, 2]]}], Join[loops, extmomsind]]] // StringTake[#, {2, -2}] &),
    "folder" -> PathName[runDirectory],
    "familyName" -> familyName,
    "problem" -> problem,
    "output" -> FileNameJoin[{runDirectory, familyName <> ".tables"}]
    |>;
  templateC2 = TemplateApply[templateC, rulesC];
  FileTemplateApply[templateC2, FileNameJoin[{runDirectory, familyName <> ".config"}]];
  (*save script*)
  templateS = FIRETemplate["Reduction"];
  rulesS = <|
    "FIRE" -> ToStringInput@$FIREInstallPath,
    "start" -> ToStringInput@FileNameJoin[{runDirectory, familyName}],
    "problem" -> ToStringInput@problem,
    "tables" -> ToStringInput@If[OptionValue["FIREUseMMA"], None, FileNameJoin[{runDirectory, familyName <> ".tables"}]],
    "target" -> ToStringInput@FileNameJoin[{runDirectory, familyName <> ".m"}],
    "save" -> ToStringInput@FileNameJoin[{runDirectory, familyName <> "save.m"}]
    |>;
  templateS2 = TemplateApply[templateS, rulesS];
  FileTemplateApply[templateS2, FileNameJoin[{runDirectory, "temp", familyName <> "save.wl"}]];
  (*Run script - this is only for manual run IBP in terminal window, see FIRERunIBP*)
  stream = OpenWrite[FileNameJoin[{runDirectory, "FIRERun.txt"}]];
  If[! OptionValue["FIREUseMMA"],
    WriteString[stream, FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}] <> " -c " <> FileNameJoin[{runDirectory, familyName}] <> ";\n"]
  ];
  WriteString[stream, StringRiffle[WolframScriptCommand[FileNameJoin[{runDirectory, "temp", familyName <> "save.wl"}]], " "] <> ";\n"];
  Close[stream];
]


ClearAll[FIRERunIBP]
FIRERunIBP::usage = "FIRERunIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}, opt:OptionsPattern[]].
\"FIREUseMMA\": (True|False) : False : use Mathematica or CXX to perform reduction.";
Options[FIRERunIBP] = {"FIREUseMMA" -> False};
FIRERunIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess, opt:OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIRERunIBP[problem, loops, {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]]
FIRERunIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}, opt:OptionsPattern[]] := Module[{logrun, logsave, runDirectory, familyName, saveScript},
  familyName = FIREFamilyName <> ToString[problem];
  runDirectory = FIRERunDirectory[FIREWorkPath, FIREFamilyName, problem];
  saveScript = FileNameJoin[{runDirectory, "temp", familyName <> "save.wl"}];
  Off[DeleteFile::fdnfnd];
  DeleteFile[FileNameJoin[{runDirectory, familyName <> "save.m"}]];
  DeleteFile[FileNameJoin[{runDirectory, "temp", familyName <> "run_log.txt"}]];
  On[DeleteFile::fdnfnd];
  (*run and save*)
  If[OptionValue["FIREUseMMA"],
    logsave = RunProcess[WolframScriptCommand[saveScript], ProcessDirectory -> runDirectory]["StandardOutput"];
    Export[FileNameJoin[{runDirectory, "temp", familyName <> "save_log.txt"}], logsave, "Text"]
    ,
    logrun = RunProcess[{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}], "-c", FileNameJoin[{runDirectory, familyName}]}, ProcessDirectory -> runDirectory]["StandardOutput"];
    Export[FileNameJoin[{runDirectory, "temp", familyName <> "run_log.txt"}], logrun, "Text"];

    logsave = RunProcess[WolframScriptCommand[saveScript], ProcessDirectory -> runDirectory]["StandardOutput"];
    Export[FileNameJoin[{runDirectory, "temp", familyName <> "save_log.txt"}], logsave, "Text"];
  ];
]


ClearAll[FIRELoadIBP]
FIRELoadIBP::usage = "FIRELoadIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}]";
FIRELoadIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, FIRELoadIBP[problem, loops, {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}]]
FIRELoadIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}] := Module[{path, legacyPath, familyName},
  familyName = FIREFamilyName <> ToString[problem];
  path = FileNameJoin[{FIRERunDirectory[FIREWorkPath, FIREFamilyName, problem], familyName <> "save.m"}];
  legacyPath = FileNameJoin[{FIREWorkPath, familyName <> "save.m"}];
  If[! FileExistsQ[path] && FileExistsQ[legacyPath], path = legacyPath];
  Get[path] /. d -> D
]


ClearAll[FIREIBPReduction]
FIREIBPReduction::usage = "FIREIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]].
Depending options: {FIREPrepareIBP, FIRERunIBP}";
Options[FIREIBPReduction] := CreateOptions[{}, {FIREPrepareIBP, FIRERunIBP}];
FIREIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIREIBPReduction[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]]
FIREIBPReduction[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]] := (
  FIREPrepareIBP[Fslist, {familyi, problem}, loops, extmomsind, kinematics, {FIREWorkPath, FIREFamilyName}, Evaluate@FilterOptions[{opt}, FIREPrepareIBP]];
  FIRERunIBP[problem, loops, {FIREWorkPath, FIREFamilyName}, Evaluate@FilterOptions[{opt}, FIRERunIBP]];
  FIRELoadIBP[problem, loops, {FIREWorkPath, FIREFamilyName}]
  )


ClearAll[FIRETemplate];
FIRETemplate = <|
"Start" -> StringTemplate["Get[`FIRE`];
Internal = `Internal`; 
External = `External`; 
Propagators = `Propagators`; 
Replacements = `Replacements`; 
PrepareIBP[];
Prepare[AutoDetectRestrictions->True,LI->True];
SaveStart[`family`];
Quit[];
"],
   
"Config" -> "#compressor `compressor`
#threads `tThreads`
#clean_databases
#fthreads `fThreads`
#sthreads `sThreads`
#variables d, `variables`
#start
#folder `folder`
#problem `problem` `familyName`.start
#integrals `familyName`.m
#output `output`",

"Reduction" -> "
Get[`FIRE`];
LoadStart[`start`, `problem`];
Burn[];
LoadTables[`tables`];
tp1 = Thread[(G @@@ #) -> (F @@@ #)] & @ Get[`target`] /. d -> D;
tp1 >> `save`;
Quit[];
"
|>;


(*old-function*)
ClearAll[FIREReductionMMA]
Options[FIREReductionMMA] := CreateOptions[{}, {FIREIBPReduction, FamilyMerge, TableS}];
FIREReductionMMA[Fslist_List, loops_List, family_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIREReductionMMA[Fslist, loops, family, p["extmomsind"], p["kinematics"], {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, opt]]
FIREReductionMMA[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, {WorkPath_String, FamilyName_String}, opt : OptionsPattern[]] := Module[{i, ibps},
  ibps = TableS[FIREIBPReduction[Fslist, {family[[i]], i}, loops, "FIREUseMMA" -> True, Evaluate@FilterOptions[{opt}, FIREIBPReduction]], {i, Length@family}, Evaluate@FilterOptions[{opt}, TableS]];
  FamilyMerge[Fslist, family, ibps, loops, extmomsind, kinematics, Evaluate@FilterOptions[{opt}, FamilyMerge]]
]

ClearAll[FIREReductionCXX]
Options[FIREReductionCXX] := CreateOptions[{}, {FIREIBPReduction, FamilyMerge, TableS}];
FIREReductionCXX[Fslist_List, loops_List, family_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIREReductionCXX[Fslist, loops, family, p["extmomsind"], p["kinematics"], {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, opt]]
FIREReductionCXX[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, {WorkPath_String, FamilyName_String}, opt : OptionsPattern[]] := Module[{i, ibps},
  ibps = TableS[FIREIBPReduction[Fslist, {family[[i]], i}, loops, "FIREUseMMA" -> False, Evaluate@FilterOptions[{opt}, FIREIBPReduction]], {i, Length@family}, Evaluate@FilterOptions[{opt}, TableS]];
  FamilyMerge[Fslist, family, ibps, loops, extmomsind, kinematics, Evaluate@FilterOptions[{opt}, FamilyMerge]]
]
