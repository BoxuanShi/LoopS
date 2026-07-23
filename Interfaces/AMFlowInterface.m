ClearAll[AMFlowCalcG]
Options[AMFlowCalcG] = {"AMFlowThread" :> LoopSParallelKernels, "AMFlowReducer" :> "FIRE+LiteRed"};

AMFlowCalcG[target_List, {Numeric_, goal_Integer, epsorder_Integer}, loops_List, family_List, process : Except[_Rule|_RuleDelayed, _String] : "CurrentProcess", opt : OptionsPattern[]] := AMFlowCalcG[target, {Numeric, goal, epsorder}, loops, family, ToExpression @ process, opt]

AMFlowCalcG[target_List, {Numeric_, goal_Integer, epsorder_Integer}, loops_List, family_List, process_Association, opt : OptionsPattern[]] := AMFlowCalcG[target, {Numeric, goal, epsorder}, loops, family, AMFlowWorkPath[process["ProcessName"]], AMFlowSaveName[loops], process["extmomsind"], process["kinematics"], opt]

AMFlowCalcG[target0_List, {Numeric0_, goal_Integer, epsorder_Integer}, loops_List, family_List, WorkPath_String, SaveName_String, extmomsind_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, target, Numeric, solve, NThread, familyname, runDirectory, save, output, varsneed, res},
  (*check avalible.*)
  If[
    If[$AMFlowInstallPath === "AMFlow`",
      Flatten[FileNames["AMFlow", #] & /@ $Path] === {},
      !FileExistsQ[$AMFlowInstallPath]],
    Print["AMFlow is not avaliable."]; Abort[]
  ];

  (*filenames*)
  familyname = (SaveName <> "S" <> ToString[#]) & /@ (Range @ Length @ family);
  runDirectory = AMFlowRunDirectory[WorkPath, SaveName, #] & /@ Range[Length@family];
  CreateDirectoryS /@ runDirectory;
  save = MapThread[FileNameJoin[{#1, #2}] &, {runDirectory, familyname}];
  output = (# <> ".wl") & /@ save;
  Print["Family files and logs are saved in separate directories under ", WorkPath, "."];
  Do[If[ValueQ @ Evaluate @ ToExpression[familyname[[i]]], Print[familyname[[i]], " is already defined. Please clear it firstly."]; Abort[]];, {i, Length @ family}];

  (*AMFlow input*)
  target = target0 // GatherGInFamily[#, family] & // GToj[#, SaveName] &;
  solve = If[#, "SolveIntegralsGaugeLink", "SolveIntegrals"] & /@ (LinearPropsExistQ[#, loops] & /@ family);
  NThread = OptionValue["AMFlowThread"];
  Numeric = Rationalize @ Numeric0;
  Print["Thread used is \"AMFlowThread\" -> ", NThread, "."];
  Print["An overall factor Exp[Length[loops]*\[Epsilon]*EulerGamma] is multiplied in the result."];

  (*check of AMFlow inputs*)
  If[!FreeQ[{Head /@ Numeric[[All, 2]], 
    getS[Numeric, _Complex] /. Complex[a_, b_] :> {a, b} &}, Real], 
    Print[Numeric0, " should be rational complex number after applying Rationalize."];
    Abort[]];
  If[!SubsetQ[Numeric[[All, 1]], 
    varsneed = Complement[Variables[{family, kinematics[[All,2]]}], 
    Flatten[{loops, Variables @ Normal[kinematics][[All, 1]]}]]], 
    Print[Numeric0, " is not complete. Need: ", varsneed, "."]; Abort[]];

  (*Run*)
  TableS[
   If[target[[i]] =!= {}
    , 
    FileTemplateApply[
     AMFTemplate, 
     <|
      "AMFlow" -> ToStringInput @ $AMFlowInstallPath,
      "IBPReducer" -> ToStringInput[OptionValue["AMFlowReducer"]],
      "Family" -> ToStringInput @ ToExpression @ familyname[[i]],
      "loops" -> ToStringInput @ loops,
      "extmomsind" -> ToStringInput @ extmomsind, 
      "kinematics" -> ToStringInput @ kinematics, 
      "family" -> ToStringInput @ (family[[i]] /. Rationalize @ Numeric), 
      "Numeric" -> ToStringInput @ Numeric, 
      "NThread" -> ToStringInput @ NThread, 
      "target" -> ToStringInput @ target[[i]], 
      "goal" -> ToStringInput @ goal, 
      "epsorder" -> ToStringInput @ epsorder, 
      "SolveIntegralsGaugeLink" -> solve[[i]], 
      "save" -> ToStringInput[save[[i]]]
      |>,
      output[[i]]
      ];
    Export[FileNameJoin[{runDirectory[[i]], "log.txt"}], RunProcess[WolframScriptCommand[output[[i]]], ProcessDirectory -> runDirectory[[i]]]["StandardOutput"] // StringSplit[#, "\n"] &, "Text"];
    , 
    None], {i, Length @ family}];

  (*import results & resturn*)
  res = Table[If[target[[i]] =!= {}, Get[save[[i]]], Nothing], {i, Length @ family}];
  Flatten @ res // amfConventionTrans[#, loops, epsorder] &
  ]


AMFTemplate = "
Get[`AMFlow`];
SetReductionOptions[\"IBPReducer\"->`IBPReducer`];
AMFlowInfo[\"Family\"]=`Family`;
AMFlowInfo[\"Loop\"]=`loops`;
AMFlowInfo[\"Leg\"]=`extmomsind`;
AMFlowInfo[\"Conservation\"]={};
AMFlowInfo[\"Replacement\"]=`kinematics`;
AMFlowInfo[\"Propagator\"]=`family`;
AMFlowInfo[\"Numeric\"]=`Numeric`;
AMFlowInfo[\"NThread\"]=`NThread`;
target=`target`;
goal=`goal`;
epsorder=`epsorder`;
res=`SolveIntegralsGaugeLink`[target,goal,epsorder];
res>>`save`;
";


ClearAll[GToj, jToG];
GToj[expr_, SaveName_String] := expr /. G[a_, b_] :> j[SaveName <> "S" <> ToString[a] // ToExpression, Sequence @@ b]
jToG[expr_] := expr /. j[a_, b___] :> G[StringCases[ToString[a], NumberString][[-1]] // ToExpression, {b}]


ClearAll[amfConventionTrans]
amfConventionTrans[rules0_List, loops_, amforder_Integer] := Module[{tp1, tp2, rules}, rules = Flatten@rules0;
  tp1 = rules[[All, 2]] /. eps -> \[Epsilon];
  tp2 = tp1 * E^(\[Epsilon] * EulerGamma * Length@loops) // Series[#, {\[Epsilon], 0, amforder - 2 * Length@loops}] & // Normal // Expand;
  Thread[rules[[All, 1]] -> tp2] // jToG]


ClearAll[AMFlowWorkPath, AMFlowSaveName, AMFlowRunDirectory]
AMFlowWorkPath[ProcessName_String] := FileNameJoin[{LoopSWorkDirectory, ProcessName, "AMFlow"}]
AMFlowSaveName[loops_List] := Module[{str, i}, 
str = StringJoin @@ Table["N", {i, Length[loops]}];
"AMFfamily" <> str <> "LO"]
AMFlowRunDirectory[workPath_String, saveName_String, problem_Integer] := FileNameJoin[{workPath, saveName <> "S" <> ToString[problem]}]
