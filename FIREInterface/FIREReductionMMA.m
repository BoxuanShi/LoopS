ClearAll[FIREReductionMMA]
Options[FIREReductionMMA] := 
  CreateOptions[{"FIREPrepareStart" -> FIREPrepareStart}, {FIREPrepareStart, 
    FIREPrepareStartMMA, FIRELoadStart, FIREGetGRules}];
FIREReductionMMA[Fslist_List, loops_List, family_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FIREReductionMMA[Fslist, loops, family, ToExpression[process], Evaluate@opt]
FIREReductionMMA[Fslist_List, loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREReductionMMA[Fslist, loops, family, process["extmomsind"], 
  process["kinematics"], FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], Evaluate@opt]
FIREReductionMMA[Fslist_List, loops_List, family_List, extmomsind_List, 
   kinematics_List, FIREWorkPath_String, FIREFamilyName_String, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, opt1, opt2, opt3, firestart},
  
  (* opt1 = FilterOptions[{opt}, OptionValue["FIREPrepareStart"]];
  Monitor[
   OptionValue["FIREPrepareStart"][loops, family, extmomsind, kinematics, 
    FIREWorkPath, FIREFamilyName, Evaluate@opt1], "FIREPrepareStart..."]; *)

 (*FIREPrepareStart*)
  firestart = 
   If[OptionValue["FIREPrepareStart"] === True, FIREPrepareStart, 
    OptionValue["FIREPrepareStart"]];
  opt1 = FilterOptions[{opt}, firestart];
  Monitor[
   firestart[loops, family, extmomsind, kinematics, FIREWorkPath, 
    FIREFamilyName, Evaluate@opt1], "FIREPrepareStart..."];
  
  opt2 = FilterOptions[{opt}, FIRELoadStart];
  Monitor[
   FIRELoadStart[loops, family, FIREWorkPath, FIREFamilyName, Evaluate@opt2], 
   "FIRELoadStart..."];
  
  (*If[OptionValue["Parallelization"],optpp=FilterOptions[{opt},
  PrepareParallel];PrepareParallel[Evaluate@optpp]];*)
  
  opt3 = FilterOptions[{opt}, FIREGetGRules];
  tp1 = Monitor[
    FIREGetGRules[Fslist, loops, family, extmomsind, kinematics, 
     Evaluate@opt3, "FIREReductionVerbose" -> False], "FIREGetGRules..."];
  
  tp1
  ]