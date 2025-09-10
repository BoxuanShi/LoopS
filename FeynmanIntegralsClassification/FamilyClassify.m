ClearAll[FamilyClassify];
(*the option "FamilyClassifySortRules" is to prevent inconsistencies \
in the family classification caused by version updates.*)
Options[FamilyClassify] := 
  CreateOptions[{"RemoveRedundancy" -> True, 
    "FamilyClassifySortRules" -> {-Length[#] &, #[[All, 
         1 ;; 3]] &}}, {FindfamilyG, LSsubsets, GetFeynInt, 
    CompleteProps, TableS, CanonicalLoops}];
FamilyClassify[propslistlist_, loops_, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FamilyClassify[propslistlist, loops, ToExpression[process], opt]

FamilyClassify[propslistlist_, loops_, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FamilyClassify[propslistlist, loops, process["kinematics"], 
  process["extmomsind"], process["moms"], opt]

FamilyClassify[propslistlist_, loops_, kinematics_, extmomsind_, 
   moms_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, j, x, y, tp0, tp1, tp2, tp3, tp4, tp5, num, familyLS, sym,
    optLS}, 
  Print["CompleteBasis is: ", 
   CompleteProps[{}, loops, 
    Evaluate@FilterOptions[{opt}, CompleteProps]]];
  tp1 = If[! FreeQ[propslistlist, FAD | SFAD | FeynAmpDenominator], 
    tp0 = GetFeynInt[{propslistlist}, loops, moms, kinematics, 
      Evaluate@FilterOptions[{opt}, GetFeynInt]];
    TableS[
     propsToLS[FADToProps[tp0[[i]], List], loops, kinematics], {i, 
      Length@tp0}, Method -> Automatic, 
     Evaluate@FilterOptions[{opt}, TableS]], 
    propsToLS /@ propslistlist];
  optLS = FilterOptions[{opt}, CanonicalLoops];
  tp2 = TableS[
    CanonicalLoops[tp1[[i]], loops, moms, kinematics, 
      Evaluate@optLS][[1]], {i, Length@tp1}, Method -> Automatic, 
    Evaluate@FilterOptions[{opt}, TableS]];
  tp3 = tp2 // 
     UnionS[#, #1[[All, 1 ;; 3]] === #2[[All, 1 ;; 3]] &] & // 
    SortBy[#, OptionValue["FamilyClassifySortRules"]] &;
  tp3[[All, All, 4]] = 1;
  tp4 = LSToprops[#, kinematics] & /@ tp3;
  Block[{Print = # &},
   Monitor[
    For[num = 1; familyLS = {{}, {}}, num <= Length@tp4, num++, 
     If[FindfamilyG[tp4[[num]], familyLS, loops, moms, kinematics, 
        "FindfamilyGDefault" -> Return[False], 
        "FGMode" -> "FamilySearch", 
        Evaluate@FilterOptions[{opt}, FindfamilyG]] === False, 
      AppendTo[familyLS[[1]], 
       CompleteProps[(sortfamily[#, loops] &)@tp4[[num]], loops, 
        extmomsind, Evaluate@FilterOptions[{opt}, CompleteProps]]];
      AppendTo[familyLS[[2]], 
       LSsubsets[tp4[[num]], loops, moms, kinematics, 
        Evaluate@FilterOptions[{opt}, LSsubsets]]]]], {num, 
     Length@tp4}]];
  If[OptionValue["RemoveRedundancy"],
   Monitor[
    sym = DeleteCases[OptionValue["Symmetry"]["Rules"], 
      x_ /; AllTrue[x, #[[1]] === #[[2]] &]];
    tp5 = 
     TableS[tp3[[i]] /. sym[[j]] // 
        CanonicalLoops[#, loops, moms, kinematics, 
           Evaluate@optLS][[1]] &, {i, Length@tp3}, {j, Length@sym}, 
       Method -> Automatic, Evaluate@FilterOptions[{opt}, TableS]] // 
      Flatten[#, 1] &;
    tp5 = Join[tp5, tp3];
    familyLS[[2]] = 
     DeleteCases[familyLS[[2]], x_ /; ! MemberQ[tp5, x[[1]]], {2}], 
    "Removing Redundancy familyLS..."]];
  
  {familyLS, familyLS[[1]]}]


ClearAll[sortfamily];
sortfamily[family_List, loops_List] := 
 Module[{}, (SortBy[#, Max@Exponent[#, loops] &] &)@family]