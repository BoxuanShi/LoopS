ClearAll[FIREGetGRules];
FIREReductionVerbose;
Options[FIREGetGRules] := 
  CreateOptions[{"FIREGetGRulesSimplify" :> SimplifyS, 
    "FIREReductionVerbose" -> True, "PreferredMIs" -> {}}, {FindRulesComplete, TableS}];
FIREGetGRules[Fslist_List, loops_List, family_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FIREGetGRules[Fslist, loops, family, ToExpression[process], 
  Evaluate[opt]]
FIREGetGRules[Fslist_List, loops_List, family_List, 
   process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  FIREGetGRules[Fslist, loops, family, process["extmomsind"], 
  process["kinematics"], Evaluate[opt]]

FIREGetGRules[Fslist0_List, loops_List, family_List, extmomsind_List, 
   kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, Fslist, Gs, GsRules, tp1, tp2, rules1, pref, prefRed, rules2, tpmi, tpeqs, tpmap},

  pref = OptionValue["PreferredMIs"];
  Fslist = Union @ Join[Fslist0, pref];
  
  tp1 = Monitor[
    FIREEvaluate[
     BlockCondition[! 
       OptionValue["FIREReductionVerbose"], {Print = (# &)}, 
      Fslist /. Dispatch[G -> F]]], "G -> F..."];
  Gs = getS[{tp1(*, FIREEvaluate[FIREMasterIntegrals[]]*)}, _G];
  
  (*any method to parallel this step?*)
  GsRules = 
   Monitor[FindRulesComplete[family, Gs, loops, kinematics, 
     extmomsind, Evaluate @ FilterOptions[{opt}, FindRulesComplete]], "FindRulesComplete..."];
  tp2 = Monitor[tp1 /. Dispatch@GsRules, 
    "Applying FindRulesComplete..."];
  rules1 = Union @ Join[Thread[Fslist -> tp2], GsRules] /. Dispatch[d -> D];
  
  Monitor[
  rules2 = If[
  pref === {}
  ,
  rules1
  ,
  prefRed = (FIREEvaluate[pref /. G -> F] /. Dispatch @ rules1);
  tpmi = prefRed // getS[#, _G]&;
  tpeqs = Thread[pref == prefRed];
  tpmap = Solve[tpeqs, tpmi][[1]];
  Thread[rules1[[All,1]] -> (rules1[[All,2]] /. Dispatch @ tpmap)]
  ];
  , "Transforming to the PreferredMIs..."];
  
  TableS[
    rules2[[i]] // Collect[#, _G, OptionValue["FIREGetGRulesSimplify"]] &, {i, Length @ rules2}, 
    "FIREGetGRules: Simplifying with option \"SimplifyFunction\".", Method -> Automatic,
    Evaluate @ FilterOptions[{opt}, TableS]]
  ]