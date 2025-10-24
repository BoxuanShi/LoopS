ClearAll[FIREEvaluate];
SetAttributes[FIREEvaluate, HoldFirst]
Options[FIREEvaluate] := CreateOptions[{"FIREdReplace" -> D}, {ParallelEvaluateS}]
FIREEvaluate[expr_, opt : OptionsPattern[]] := ParallelEvaluateS[expr, 1, Evaluate @ opt] /. d -> OptionValue["FIREdReplace"]


ClearAll[FIREGetGRules];
FIREReductionVerbose;
Options[FIREGetGRules] := CreateOptions[{"FIREGetGRulesSimplify" :> SimplifyS, "FIREReductionVerbose" -> True, "PreferredMIs" -> {}}, {FindRulesComplete, TableS}];

FIREGetGRules[Fslist_List, loops_List, family_List, {ibprules_Dispatch, ibpgAndMI_List}, process_Association : CurrentProcess, opt : OptionsPattern[]] := FIREGetGRules[Fslist, loops, family, {ibprules, ibpgAndMI}, process["extmomsind"], process["kinematics"], Evaluate[opt]]

FIREGetGRules[Fslist0_List, loops_List, family_List, {ibprules_Dispatch, ibpgAndMI_List}, extmomsind_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, Fslist, Gs, GsRules, tp1, tp2, rules1, pref, prefRed, rules2, tpmi, tpeqs, tpmap},

  pref = OptionValue["PreferredMIs"];
  Fslist = Join[Fslist0, pref];

  tp1 = Fslist // ApplyIBPRules[#, {ibprules, ibpgAndMI}]&;
  Gs = tp1 // getG[#, _G]&;
  
  GsRules = Monitor[FindRulesComplete[family, Gs, loops, {ibprules, ibpgAndMI}, kinematics, extmomsind, Evaluate @ FilterOptions[{opt}, FindRulesComplete]], "FindRulesComplete..."];
  tp2 = tp1 /. Dispatch@GsRules;
  rules1 = Union@Join[Thread[Fslist -> tp2], GsRules];

  Monitor[
  rules2 = If[pref === {},
    rules1,
    prefRed = (ApplyIBPRules[pref, {ibprules, ibpgAndMI}] /. Dispatch@rules1);
    tpmi = prefRed // getS[#, _G]&;
    tpeqs = Thread[pref == prefRed];
    tpmap = Solve[tpeqs, tpmi][[1]];
    Thread[rules1[[All,1]] -> (rules1[[All,2]] /. Dispatch @ tpmap)]
  ];
  , "Transforming to the PreferredMIs..."];

  TableS[
    rules2[[i]] // Collect[#, _G, OptionValue["FIREGetGRulesSimplify"]] &, {i, Length @ rules2}, "FIREGetGRules: Simplifying with option \"SimplifyFunction\".", Method -> Automatic, Evaluate @ FilterOptions[{opt}, TableS]]
  ]


ClearAll[FIRELoadStart]
Options[FIRELoadStart] = {"FIREVerbose" -> False};
FIRELoadStart[loops_List, family_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := FIRELoadStart[loops, family, FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], opt]
FIRELoadStart[loops_List, family_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{i},
  CloseKernels[];
  Print["Kernels are closed."];
  PrepareParallel[1];
  FIREEvaluate[BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
    Do[LoadStart[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}], i], {i, Length@family}];
    Burn[];]
   ];
  Print["Starts are loaded. Use FIREEvaluate to work in the first kernel."]
  ]


ClearAll[FIRELoadTable]
Options[FIRELoadTable] = {"FIREVerbose" -> False};
FIRELoadTable[loops_List, family_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := FIRELoadTable[loops, family, FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], opt]
FIRELoadTable[loops_List, family_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{i, tp1, ibprules, ibpgAndMI},
  If[Union@Table[FileExistsQ[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".tables"}]], {i, Length@family}] === {True},
    Nothing,
    Print["Tables are abscent."]; Abort[]];
  FIREEvaluate[BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
    LoadTables[Table[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".tables"}], {i, Length@family}]]]
   ];
  Print["Tables are loaded."];
  ]

ClearAll[GatherGInFamily]
GatherGInFamily[Glist_List, family_List] := Module[{Glist2, Glist3},
  Glist2 = Join[Glist, G[#, "x"] & /@ (Range@Length@family)];
  Glist3 = Glist2 // GatherBy[#, #[[1]] &] & // SortBy[#, #[[1, 1]] &] &;
  DeleteCases[#, G[_, "x"]] & /@ Glist3
  ]


ClearAll[FIREPrepareCXX]
Options[FIREPrepareCXX] := CreateOptions[{"compressor" -> "none", "FIRECXXKernels" :> LoopSParallelKernels}, {FindCompleteGList}];

FIREPrepareCXX[Fslist_List, loops_List, family_List, process_String : "CurrentProcess", opt : OptionsPattern[]] := FIREPrepareCXX[Fslist, loops, family, ToExpression[process], Evaluate@opt]

FIREPrepareCXX[Fslist_List, loops_List, family_List, process_Association, opt : OptionsPattern[]] := FIREPrepareCXX[Fslist, loops, family, process["extmomsind"], process["kinematics"], FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], Evaluate@opt]

FIREPrepareCXX[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{i, rulesConfig, Fslist2, FlistFamily},
  
  If[Head[$FIREInstallPath] =!= String, Print["Set $FIREInstallPath firstly."]; Abort[]];
  
  (*separate Fslist by family and export to FIREWorkPath*)
  Fslist2 = FindCompleteGList[Fslist, family, loops, kinematics, Evaluate@FilterOptions[{opt}, FindCompleteGList]];
  FlistFamily = GatherGInFamily[Fslist2, family];
  FlistFamily = FlistFamily /. Dispatch[G -> List];
  TableS[Export[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".m"}], FlistFamily[[i]]], {i, Length@family}, "Exporting target integrals..."];
  
  (*generate config file for FIRECXX*)
  Table[
   rulesConfig = <|
     "compressor" -> OptionValue["compressor"],
     "fThreads" -> OptionValue["FIRECXXKernels"],
     "tThreads" -> Ceiling[OptionValue["FIRECXXKernels"]/2],
     "sThreads" -> Ceiling[OptionValue["FIRECXXKernels"]/2],
     "variables" -> (ToString[Complement[Variables[{family, kinematics[[All, 2]]}], Join[loops, extmomsind]]] // StringTake[#, {2, -2}] &),
     "folder" -> PathName[FIREWorkPath],
     "familyName" -> (FIREFamilyName <> ToString[i]),
     "problem" -> i,
     "output" -> FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".tables"}]
     |>;
   Export[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".config"}], TemplateApply[FIRETemplate["Config"], rulesConfig], "Text"]
   , {i, Length@family}];
  
  (*RunProcess-export*)
  Export[FileNameJoin[{FIREWorkPath, "FIRERun.txt"}], 
  StringJoin @@ Table[FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}] <> " -c " <> FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}] <> ";", {i, Length@family}], 
  "Text"];
  
  Print["Kernels prepared for FIRE is FIRECXXKernels -> ", OptionValue["FIRECXXKernels"], "."]
  ]


ClearAll[FIREPrepareStart];
FIREVerbose;
Options[FIREPrepareStart] := CreateOptions[{"FIREVerbose" -> False}, {TableS}]
FIREPrepareStart[loops_List, family_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := FIREPrepareStart[loops, family, process["extmomsind"], process["kinematics"], FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], Evaluate@opt]
FIREPrepareStart[loops_List, family_List, extmomsind_List, kinematics_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{i, template, rule},

  CreateDirectoryS@FIREWorkPath;

  If[!FileExistsQ[$FIREInstallPath] || !StringMatchQ[FileNameTake@$FIREInstallPath, "FIRE" ~~ __ ~~ ".m"], Print["$FIREInstallPath is wrong."]; Abort[]];

  (*FileTemplateApply*)
  template = FIRETemplate["Start"];
  Table[
    rule = <|
      "FIRE" -> ToStringInput@$FIREInstallPath,
      "Internal" -> ToStringInput@loops,
      "External" -> ToStringInput@extmomsind,
      "Propagators" -> ToStringInput@family[[i]],
      "Replacements" -> ToStringInput@kinematics,
      "family" -> ToStringInput@FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]
      |>;
    FileTemplateApply[template, rule, FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".wl"}]]
    , {i, Length@family}];
  
   (*RunProcess*)
  TableS[RunProcess[{"wolframscript", "-file", FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".wl"}]}], {i, Length@family}, Evaluate@FilterOptions[{opt}, TableS]];
   
  Print["Starts are prepared."]
  ];


ClearAll[FIREPrepareStartMMA]
Options[FIREPrepareStartMMA] := CreateOptions[{"FIREVerbose" -> False}, {PrepareParallel}];
FIREPrepareStartMMA[loops_List, family_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FIREPrepareStartMMA[loops, family, ToExpression[process], Evaluate@opt]
FIREPrepareStartMMA[loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareStartMMA[loops, family, process["extmomsind"], 
  process["kinematics"], FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], Evaluate@opt]
FIREPrepareStartMMA[loops_List, family_List, extmomsind_List, kinematics_List,
    FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{i, tp1},
  FIREParallel[
   BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
     AppendTo[$ContextPath, "FIRE`"];
     Internal = loops;
     External = extmomsind;
     Propagators = family[[i]];
     Replacements = kinematics;
     PrepareIBP[];
     Prepare[AutoDetectRestrictions -> True, LI -> True];
     SaveStart[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]]];
   ,
   {i, 1, Length@family}, OptionValue["Kernels"]];
  
  Print["Starts are prepared."]
  ]

ClearAll[FIREParallel]
SetAttributes[FIREParallel, HoldAll]
FIREParallel[body_, {pindex_, ini_, fin_}, paraNum_] := 
 Module[{re, cycf, kernellist, paraRang, ig},
  cycf = (fin - ini + 1)/paraNum;(*number of cycle minus 1*)
  cycf = If[IntegerQ[cycf], cycf - 1, cycf // IntegerPart];
  re = Monitor[
     Table[CloseKernels[];
      LaunchKernels[paraNum];
      kernellist = 
       ParallelEvaluate[$KernelID];(*get kernel ID for given number of \
kernels*)
      Table[
       ParallelEvaluate[pindex = ini + paraNum*cyc + ig - 1, 
        kernellist[[ig]]], {ig, 
        paraNum}];(*define the corresponding pindex in the kernels*)
      paraRang = 
       kernellist[[
        1 ;; Length[
          Intersection[Range[fin - ini + 1], 
           Range[paraNum*cyc + 1, 
            paraNum*(cyc + 1)]]]]];(*decide which kernel to run*)
      ParallelEvaluate[body, paraRang](*evaluate and return the results*)
      , {cyc, 0, cycf}]
     , {cyc*paraNum, fin}] // Flatten[#, 1] &;
  CloseKernels[];
  re
  ]

ClearAll[FIREReductionCXX]
FIREReductionCXX::usage = "FIREReductionCXX[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]].";
Options[FIREReductionCXX] := CreateOptions[{"FIREPrepareStart" -> FIREPrepareStart}, {FIREPrepareStart, FIREPrepareStartMMA, FIREPrepareCXX, FIRERunCXX, FIRELoadStart, FIRELoadTable, FIREGetGRules}];

FIREReductionCXX[Fslist_List, loops_List, family_List, process_String : "CurrentProcess", opt : OptionsPattern[]] := FIREReductionCXX[Fslist, loops, family, ToExpression[process], Evaluate @ opt]

FIREReductionCXX[Fslist_List, loops_List, family_List, process_Association, opt : OptionsPattern[]] := FIREReductionCXX[Fslist, loops, family, process["extmomsind"], 
process["kinematics"], FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], Evaluate @ opt]

FIREReductionCXX[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{i, firestart, Fslist2, FlistFamily, tp1, opt1, opt2, opt3, opt4, opt5, rx, sx, dx},

  {rx, sx, dx} = OptionValue["PossibleMIsInSector"];

  (*FIREPrepareStart*)
  If[OptionValue["FIREPrepareStart"] === True, Monitor[FIREPrepareStart[loops, family, extmomsind, kinematics, FIREWorkPath, FIREFamilyName, Evaluate@FilterOptions[{opt}, firestart]], "FIREPrepareStart..."]];
  
  (*FIREPrepareCXX*)
  opt5 = FilterOptions[{opt}, FIREPrepareCXX];
  FIREPrepareCXX[Fslist, loops, family, extmomsind, kinematics, FIREWorkPath, FIREFamilyName, Evaluate@opt5];
  
  (*FIRERunCXX*)
  FIRERunCXX[loops, family, FIREWorkPath, FIREFamilyName];
  
  (*FIRELoadStart*)
  opt2 = FilterOptions[{opt}, FIRELoadStart];
  Monitor[FIRELoadStart[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt2], "FIRELoadStart..."];
  
  (*FIRELoadTable*)
  opt4 = FilterOptions[{opt}, FIRELoadTable];
  Monitor[FIRELoadTable[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt4], "FIRELoadTable..."];
  
  (*FIRESaveIBP*)
  FIRESaveIBP[Fslist];

  (*FIREGetGRules*)
  opt3 = FilterOptions[{opt}, FIREGetGRules];
  tp1 = Monitor[FIREGetGRules[Fslist, loops, family, extmomsind, kinematics, "FIREReductionVerbose" -> True, Evaluate@opt3], "FIREGetGRules..."];
  
  tp1
  ]


ClearAll[FIREReductionMMA]
Options[FIREReductionMMA] := CreateOptions[{"FIREPrepareStart" -> True}, {FIREPrepareStart, FIREPrepareStartMMA, FIRELoadStart, FIREGetGRules}];

FIREReductionMMA[Fslist_List, loops_List, family_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := FIREReductionMMA[Fslist, loops, family, process["extmomsind"], process["kinematics"], FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], Evaluate@opt]

FIREReductionMMA[Fslist_List, loops_List, family_List, extmomsind_List, kinematics_List, FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := Module[{tp1, opt1, opt2, opt3, firestart, fireins},

  (*in the case user defined $FIREInstallPath doesn't work, switch to LoopS's.*)
  fireins = $FIREInstallPath;
  If[!FileExistsQ[$FIREInstallPath],
  $FIREInstallPath = FileNameJoin[{$LoopSInstallPath, "LoadDependencies", "Dependencies", "fire", "FIRE6", "FIRE6.m"}]];

  (*FIREPrepareStart*)
  firestart = If[OptionValue["FIREPrepareStart"] === True, FIREPrepareStart, OptionValue["FIREPrepareStart"]];
  opt1 = FilterOptions[{opt}, firestart];
  Monitor[firestart[loops, family, extmomsind, kinematics, FIREWorkPath, FIREFamilyName, Evaluate@opt1], "FIREPrepareStart..."];
  
  opt2 = FilterOptions[{opt}, FIRELoadStart];
  Monitor[FIRELoadStart[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt2], "FIRELoadStart..."];

  opt3 = FilterOptions[{opt}, FIREGetGRules];

  tp1 = Monitor[
    FIREGetGRules[Fslist, loops, family, extmomsind, kinematics, Evaluate@opt3, "FIREReductionVerbose" -> False]
    , "FIREGetGRules..."];
  $FIREInstallPath = fireins;

  tp1
  ]


ClearAll[FIRERunCXX]
FIRERunCXX[loops_List, family_List, process_String : "CurrentProcess"] := FIRERunCXX[loops, family, ToExpression[process]]
FIRERunCXX[loops_List, family_List, process_Association] := FIRERunCXX[loops, family, FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops]]
FIRERunCXX[loops_List, family_List, FIREWorkPath_String, FIREFamilyName_String] := Module[{i},
  If[Head[$FIREInstallPath] =!= String, 
   Print["Set $FIREInstallPath firstly."]; Abort[]];
  TableS[RunProcess[{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}], "-c", FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]}]
   , {i, Length@family}, "Reducing target integrals..."];
  ]


ClearAll[FIRESaveIBP];
FIRESaveIBP::usage = "FIRESaveIBP[Fslist_List, family_List, opt : OptionsPattern[]].";
Option[FIRESaveIBP] = {"FIREReductionVerbose" -> True};
FIRESaveIBP[Fslist_List, opt : OptionsPattern[]] := Module[{tp1, tp2, ibprules, ibpgAndMI},
    tp1 = FIREEvaluate[BlockCondition[!OptionValue["FIREReductionVerbose"], {Print = (# &)}, Fslist /. G -> F]];
    tp1 = tp1 /. d -> D;
    ibpgAndMI = getS[{Fslist, tp1}, _G];
    ibprules = Dispatch @ Thread[Fslist -> tp1];
    {ibprules, ibpgAndMI}
  ]


FIREMasterIntegrals[] := FIREEvaluate[G @@@ MasterIntegrals[]]