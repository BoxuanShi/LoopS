FIREGetGRules;

ClearAll[FIREGetGRules];
FIREReductionVerbose;
Options[FIREGetGRules] := 
  CreateOptions[{"FIREGetGRulesSimplify" :> SimplifyS, 
    "FIREReductionVerbose" -> False}, {FindRulesComplete, TableS}];
FIREGetGRules[Fslist_List, loops_List, family_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FIREGetGRules[Fslist, loops, family, ToExpression[process], Evaluate[opt]]
FIREGetGRules[Fslist_List, loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREGetGRules[Fslist, loops, family, process["extmomsind"], 
  process["kinematics"], Evaluate[opt]]

FIREGetGRules[Fslist_List, loops_List, family_List, extmomsind_List, 
   kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, Gs, GsRules, tp1, tp2, tp3, tp4, block, optf2, opttable},
  
  tp1 = Monitor[
    BlockCondition[! OptionValue["FIREReductionVerbose"], {Print = (# &)}, 
     FIREEvaluate[Fslist /. Dispatch[G -> F]]], "G -> F..."];
  
  Gs = getS[{tp1, FIREEvaluate[MasterIntegralsS[]]}, _G];
  
  (*any method to parallel this step?*)
  optf2 = FilterOptions[{opt}, FindRulesComplete];
  GsRules = Monitor[
    FindRulesComplete[family, Gs, loops, kinematics, extmomsind, 
     Evaluate@optf2]
    , "FindRulesComplete..."];
  
  tp2 = Monitor[tp1 /. Dispatch@GsRules, "Applying FindRulesComplete..."];
  tp3 = Union@Join[Thread[Fslist -> tp2], GsRules] /. Dispatch[d -> D];
  
  opttable = FilterOptions[{opt}, TableS];
  tp4 =
   TableS[
    tp3[[i]] // Collect[#, _G, OptionValue["FIREGetGRulesSimplify"]] &, {i, 
     Length@tp3}, 
    "FIREGetGRules: Simplifying with option \"SimplifyFunction\".", 
    Evaluate@opttable];
  
  Monitor[Dispatch[tp4], "Dispatching..."]
  ]