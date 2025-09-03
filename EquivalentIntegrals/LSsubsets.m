LSsubsets;

ClearAll[LSsubsets]
Options[LSsubsets] := 
  CreateOptions[{"Parallelization" -> False, "LSsubsetsRange" -> 1}, {TableS, 
    CanonicalLoops}];
LSsubsets[propslist_List, loops_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 LSsubsets[propslist, loops, ToExpression[process], opt]
LSsubsets[propslist_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 LSsubsets[propslist, loops, process["moms"], process["kinematics"], opt]
LSsubsets[propslist_List, loops_List, moms_List, kinematics_List, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, a, rg0, rg, sym, tp0, tp1, tp1x, tp2, tp3, tp4, opttable, optLS},
  rg0 = OptionValue["LSsubsetsRange"];
  rg = {If[rg0 == 1, Length@loops, rg0], Length@propslist};
  
  tp1 = Subsets[propslist, rg];
  tp1x = DeleteCases[tp1, a_ /; zeroSectorQ[a, loops, kinematics], {1}];
  tp2 = propsToLS[#, loops, kinematics] & /@ tp1x;
  
  opttable = FilterOptions[{opt}, TableS];
  optLS = FilterOptions[{opt}, CanonicalLoops];
  tp3 = Block[{Monitor = (# &)}, 
    TableS[CanonicalLoops[tp2[[i]], loops, moms, kinematics, Method -> Automatic, 
      Evaluate@optLS], {i, Length@tp2}, Evaluate@opttable]];
  tp4 = GatherBy[tp3, #[[1]] &][[All, 1]];
  
  tp4
  ]


ClearAll[GenerateFamilyLS]
Options[GenerateFamilyLS] := CreateOptions[{}, {LSsubsets, TableS}];
GenerateFamilyLS[family_List, loops_List, 
  CurrentProcess_String : "CurrentProcess", opt : OptionsPattern[]] :=
  GenerateFamilyLS[family, loops, ToExpression@CurrentProcess, 
  Evaluate@opt]
GenerateFamilyLS[family_List, loops_List, CurrentProcess_Association, 
  opt : OptionsPattern[]] := 
 GenerateFamilyLS[family, loops, CurrentProcess["moms"], 
  CurrentProcess["kinematics"], Evaluate@opt]
GenerateFamilyLS[family_List, loops_List, moms_List, kinematics_List, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, tp1, tp2, tp3, opttable},
  tp1 = TableS[
    LSsubsets[family[[i]], loops, moms, kinematics], {i, 
     Length@family}, Evaluate@FilterOptions[{opt}, TableS]];
  (* tp1 = tp1 // Transpose; *)
  {family, tp1}]