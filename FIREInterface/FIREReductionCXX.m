FIREReductionCXX;

ClearAll[FIREReductionCXX]
FIREReductionCXX::usage = 
  "FIREPrepareStart + FIREPrepareCXX + FIRERunCXX + FIRELoadStart + \
FIRELoadTable + FIREGetGRules.";
Options[FIREReductionCXX] := 
  CreateOptions[{"FIREPrepareStart" -> FIREPrepareStart}, {FIREPrepareStart, 
    FIREPrepareStartMMA, FIREPrepareCXX, FIRERunCXX, FIRELoadStart, 
    FIRELoadTable, FIREGetGRules}];
FIREReductionCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREReductionCXX[Fslist, loops, family, rx, sx, dx, ToExpression[process], 
  Evaluate@opt]
FIREReductionCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREReductionCXX[Fslist, loops, family, rx, sx, dx, process["extmomsind"], 
  process["kinematics"], FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], Evaluate@opt]
FIREReductionCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, extmomsind_List, kinematics_List, 
   FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{i, firestart, rulesConfig, Fslist2, FlistFamily, tp1, opt1, opt2, 
   opt3, opt4, opt5, optpp},
  
  (*FIREPrepareStart*)
  firestart = 
   If[OptionValue["FIREPrepareStart"] === True, FIREPrepareStart, 
    OptionValue["FIREPrepareStart"]];
  opt1 = FilterOptions[{opt}, firestart];
  Monitor[
   firestart[loops, family, extmomsind, kinematics, FIREWorkPath, 
    FIREFamilyName, Evaluate@opt1], "FIREPrepareStart..."];
  
  (*FIREPrepareCXX*)
  opt5 = FilterOptions[{opt}, FIREPrepareCXX];
  FIREPrepareCXX[Fslist, loops, family, rx, sx, dx, extmomsind, kinematics, 
   FIREWorkPath, FIREFamilyName, Evaluate@opt5];
  
  (*FIRERunCXX*)
  FIRERunCXX[loops, family, FIREWorkPath, FIREFamilyName];
  
  (*FIRELoadStart*)
  opt2 = FilterOptions[{opt}, FIRELoadStart];
  Monitor[
   FIRELoadStart[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt2], 
   "FIRELoadStart..."];
  
  (*FIRELoadTable*)
  opt4 = FilterOptions[{opt}, FIRELoadTable];
  Monitor[
   FIRELoadTable[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt4], 
   "FIRELoadTable..."];
  
  (*PrepareParallel*)
  (*If[OptionValue[Parallelization],optpp=FilterOptions[{opt},PrepareParallel];
  PrepareParallel[Evaluate@optpp]];*)
  
  (*FIREGetGRules*)
  opt3 = FilterOptions[{opt}, FIREGetGRules];
  tp1 = Monitor[
    FIREGetGRules[Fslist, loops, family, extmomsind, kinematics, 
     "FIREReductionVerbose" -> True, Evaluate@opt3], "FIREGetGRules..."];
  
  tp1
  ]