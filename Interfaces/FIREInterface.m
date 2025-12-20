ClearAll[FIREWorkPath, FIREFamilyName];
FIREWorkPath[ProcessName_String] := FileNameJoin[{LoopSWorkDirectory, ProcessName, "IBPReduction" , "FIRE"}];
FIREFamilyName[loops_List] := Module[{str}, str = StringJoin @@ Table["N", {i, Length@loops}]; "family" <> str <> "LO"]


ClearAll[FIREPrepareIBP];
FIREPrepareIBP::usage = "FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]].
\"FIREcompressor\": _ : \"none\" : compressor in config file.
\"IBPKernels\": _Integer : LoopSParallelKernels : fThreads in config file.
\"FIREUseMMA\": (True|False) : False : use Mathematica or CXX to perform reduction.
Depending options: {FindCompleteGList}";
Options[FIREPrepareIBP] := CreateOptions[{"FIREcompressor" -> "none", "IBPKernels" :> LoopSParallelKernels, "FIREUseMMA" -> False}, {FindCompleteGList}];
FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIREPrepareIBP[Fslist, {familyi, problem}, loops, p["extmomsind"], p["kinematics"], {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]]
FIREPrepareIBP[Fslist_List, {familyi_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {FIREWorkPath_String, FIREFamilyName_String}, opt : OptionsPattern[]] := Module[{i, x, Fslist2, FlistFamily, stream, startfile, template, rules, template2, startscript, templateC, rulesC, templateC2, templateS, rulesS, templateS2, log},
  (*check install*)
  If[!FileExistsQ[$FIREInstallPath] || !StringMatchQ[FileNameTake@$FIREInstallPath, "FIRE" ~~ __ ~~ ".m"], Print["$FIREInstallPath is wrong."]; Abort[]];
  (*create directories*)
  Off[CreateDirectory::eexist];
  CreateDirectoryS@FIREWorkPath;
  CreateDirectoryS@FileNameJoin[{FIREWorkPath, "temp"}];
  On[CreateDirectory::eexist];
  (*start file*)
  template = FIRETemplate["Start"];
  startfile = FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem]}];
  rules = <|
    "FIRE" -> ToStringInput@$FIREInstallPath,
    "Internal" -> ToStringInput@loops,
    "External" -> ToStringInput@extmomsind,
    "Propagators" -> ToStringInput@familyi,
    "Replacements" -> ToStringInput@kinematics,
    "family" -> ToStringInput@startfile
    |>;
  template2 = TemplateApply[template, rules];
  startscript = FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "start.wl"}];
  If[FileExistsQ[startfile <> ".start"] && Quiet[ToExpression[Import[startscript, "Text"], InputForm, Hold] === ToExpression[template2, InputForm, Hold]],
      Nothing,
      FileTemplateApply[template2, startscript];
      log = RunProcess[{"wolframscript", "-file", startscript}]["StandardOutput"];
      Export[FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "start_log.txt"}], log, "Text"];
    ];
  (*target file*)
  Fslist2 = DeleteCases[Fslist, x_ /; x[[1]] =!= problem];
  FlistFamily = FindCompleteGList[Fslist2, ReplacePart[ConstantArray[{}, problem], -1 -> familyi], loops, kinematics, Evaluate@FilterOptions[{opt}, FindCompleteGList]];
  FlistFamily = FlistFamily /. G -> List;
  Export[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".m"}], FlistFamily];
  (*config file*)
  templateC = FIRETemplate["Config"];
  rulesC = <|
    "compressor" -> OptionValue["FIREcompressor"],
    "fThreads" -> OptionValue["IBPKernels"],
    "tThreads" -> Ceiling[OptionValue["IBPKernels"]/2],
    "sThreads" -> Ceiling[OptionValue["IBPKernels"]/2],
    "variables" -> (ToString[Complement[Variables[{familyi, kinematics[[All, 2]]}], Join[loops, extmomsind]]] // StringTake[#, {2, -2}] &),
    "folder" -> PathName[FIREWorkPath],
    "familyName" -> (FIREFamilyName <> ToString[problem]),
    "problem" -> problem,
    "output" -> FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".tables"}]
    |>;
  templateC2 = TemplateApply[templateC, rulesC];
  FileTemplateApply[templateC2, FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".config"}]];
  (*save file*)
  templateS = FIRETemplate["Reduction"];
  rulesS = <|
    "FIRE" -> ToStringInput@$FIREInstallPath,
    "start" -> ToStringInput@FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem]}],
    "problem" -> ToStringInput@problem,
    "tables" -> ToStringInput@If[OptionValue["FIREUseMMA"], None, FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".tables"}]],
    "target" -> ToStringInput@FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".m"}],
    "save" -> ToStringInput@FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> "save.m"}]
    |>;
  templateS2 = TemplateApply[templateS, rulesS];
  FileTemplateApply[templateS2, FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "save.wl"}]];
  (*Run file - this is only for manual run IBP in terminal window, see FIRERunIBP*)
  stream = OpenWrite[FileNameJoin[{FIREWorkPath, "FIRERun" <> ToString[Length@loops] <> ".txt"}]];
  Do[
    If[
      FileExistsQ[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".config"}]], 
      WriteString[stream, FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}] <> " -c " <> FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}] <> ";\n"];
      If[
        OptionValue["FIREUseMMA"],
        WriteString[stream, StringRiffle@{"wolframscript", "-file", FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[i] <> "save.wl"}],";\n"}],
        WriteString[stream, StringRiffle@{"wolframscript", "-file", FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[i] <> "save.wl"}],";\n"}]
        (* WriteString[stream, StringRiffle@{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", "tables2rules"}], FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".tables"}], FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> "save.m"}]} <> ";\n"] *)
      ],
      Break[]
    ]
    , {i, Infinity}];
  Close[stream];
]


ClearAll[FIRERunIBP]
FIRERunIBP::usage = "FIRERunIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}, opt:OptionsPattern[]].
\"FIREUseMMA\": (True|False) : False : use Mathematica or CXX to perform reduction.";
Options[FIRERunIBP] = {"FIREUseMMA" -> False};
FIRERunIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess, opt:OptionsPattern[]] := Module[{p=ReleaseHold@process}, FIRERunIBP[problem, loops, {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]]
FIRERunIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}, opt:OptionsPattern[]] := Module[{logrun, logsave},
  Off[DeleteFile::fdnfnd];
  DeleteFile[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> "save.m"}]];
  DeleteFile[FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "run_log.txt"}]];
  On[DeleteFile::fdnfnd];
  (*run and save*)
  If[OptionValue["FIREUseMMA"],
    logsave = RunProcess[{"wolframscript", "-file", FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "save.wl"}]}]["StandardOutput"];
    Export[FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "save_log.txt"}], logsave, "Text"]
    ,
    logrun = RunProcess[{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}], "-c", FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem]}]}]["StandardOutput"];
    Export[FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "run_log.txt"}], logrun, "Text"];

    logsave = RunProcess[{"wolframscript", "-file", FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "save.wl"}]}]["StandardOutput"];
    (* logsave = RunProcess[{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", "tables2rules"}], FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> ".tables"}], FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> "save.m"}]}]["StandardOutput"]; *)
    Export[FileNameJoin[{FIREWorkPath, "temp", FIREFamilyName <> ToString[problem] <> "save_log.txt"}], logsave, "Text"];
  ];s
]


ClearAll[FIRELoadIBP]
FIRELoadIBP::usage = "FIRELoadIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}]";
FIRELoadIBP[problem_Integer, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, FIRELoadIBP[problem, loops, {FIREWorkPath[p["ProcessName"]], FIREFamilyName[loops]}]]
FIRELoadIBP[problem_Integer, loops_List, {FIREWorkPath_String, FIREFamilyName_String}] := Module[{path},
  path = FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[problem] <> "save.m"}];
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
