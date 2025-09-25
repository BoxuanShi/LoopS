ClearAll[FamilyClassify];
(*the option "FamilyClassifySortRules" is to prevent inconsistencies \
in the family classification caused by version updates.*)
Options[FamilyClassify] := 
  CreateOptions[{"RemoveRedundancy" -> True, 
    "FamilyClassifySortRules" -> {-Length[#] &, #[[All, 1 ;; 3]] &}, 
    "UserDefinedFamily" -> {}}, {FindfamilyG, LSsubsets, GetFeynInt, 
    CompleteProps, TableS, CanonicalLoops, GenerateFamilyLS}];
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
 Module[{i, j, x, y, tp2, tp4, tp5, num, familyLS, RDQ, tpf}, 

  Print["CompleteBasis is: ", 
   CompleteProps[{}, loops, 
    Evaluate@FilterOptions[{opt}, CompleteProps]]];

  $familyclassifytp1 = If[! FreeQ[propslistlist, FAD | SFAD | FeynAmpDenominator], 
    $familyclassifytp0 = GetFeynInt[{propslistlist}, loops, moms, kinematics, 
      Evaluate@FilterOptions[{opt}, GetFeynInt]];
  If[OptionValue["Parallelization"], DumpDistribute[{$familyclassifytp0}]];
    TableS[
     propsToLS[FADToProps[$familyclassifytp0[[i]], List], loops, kinematics], {i, 
      Length@$familyclassifytp0}, Method -> Automatic, DistributedContexts -> None, 
     Evaluate@FilterOptions[{opt}, TableS]], 
    propsToLS /@ propslistlist];

  $familyclassifyoptLS = FilterOptions[{opt}, CanonicalLoops];
  If[OptionValue["Parallelization"], DumpDistribute[{$familyclassifytp1, $familyclassifyoptLS}]];
  tp2 = TableS[
    CanonicalLoops[$familyclassifytp1[[i]], loops, moms, kinematics, 
      Evaluate@$familyclassifyoptLS][[1]], {i, Length@$familyclassifytp1}, Method -> Automatic, DistributedContexts -> None, 
    Evaluate@FilterOptions[{opt}, TableS]];

  $familyclassifytp3 = tp2 // 
     UnionS[#, #1[[All, 1 ;; 3]] === #2[[All, 1 ;; 3]] &] & // 
    SortBy[#, OptionValue["FamilyClassifySortRules"]] &;
  
  $familyclassifytp3[[All, All, 4]] = 1;

  tp4 = LSToprops[#, kinematics] & /@ $familyclassifytp3;
  
  
  RDQ = OptionValue["RemoveRedundancy"];
  If[RDQ,
   $familyclassifysym = 
    DeleteCases[OptionValue["Symmetry"]["Rules"], 
     x_ /; AllTrue[x, #[[1]] === #[[2]] &]];

  If[OptionValue["Parallelization"], DumpDistribute[{$familyclassifytp3, $familyclassifysym}]];
   tp5 = 
    TableS[$familyclassifytp3[[i]] /. $familyclassifysym[[j]] // 
       CanonicalLoops[#, loops, moms, kinematics, 
          Evaluate @ $familyclassifyoptLS][[1]] &, {i, Length@$familyclassifytp3}, {j, Length@$familyclassifysym}, 
      Method -> Automatic, DistributedContexts -> None, Evaluate @ FilterOptions[{opt}, TableS]] // 
     Flatten[#, 1] &;
   tp5 = Join[tp5, $familyclassifytp3]];
  
  
  familyLS = 
   GenerateFamilyLS[OptionValue["UserDefinedFamily"], loops, moms, 
    kinematics, Evaluate @ FilterOptions[{opt}, GenerateFamilyLS]];
  If[RDQ, 
   familyLS[[2]] = 
    DeleteCases[familyLS[[2]], x_ /; ! MemberQ[tp5, x[[1]]], {2}]];
  
  
  Block[{Print = # &}, Monitor[
    For[num = 1, num <= Length @ tp4, num++, 
     If[FindfamilyG[tp4[[num]], familyLS, loops, moms, kinematics, 
        "FindfamilyGFailedReturn" -> Return[False], 
        "FindfamilyGMode" -> "FamilyExistQ", 
        Evaluate@FilterOptions[{opt}, FindfamilyG]] === False, 
      AppendTo[familyLS[[1]], 
       CompleteProps[(sortfamily[#, loops] &)@tp4[[num]], loops, 
        extmomsind, Evaluate@FilterOptions[{opt}, CompleteProps]]];
      tpf = 
       LSsubsets[tp4[[num]], loops, moms, kinematics, 
        Evaluate@FilterOptions[{opt}, LSsubsets]];
      If[RDQ, 
       tpf = DeleteCases[tpf, x_ /; ! MemberQ[tp5, x[[1]]], {1}]];
      AppendTo[familyLS[[2]], tpf];
      ]
     ], {num, Length@tp4}]];

  Clear[$familyclassifyoptLS, $familyclassifysym, $familyclassifytp0, $familyclassifytp1, $familyclassifytp3];
  If[OptionValue["Parallelization"], ParallelEvaluate[Clear[$familyclassifyoptLS, $familyclassifysym, $familyclassifytp0, $familyclassifytp1, $familyclassifytp3]]];
  
  {familyLS, familyLS[[1]]}]


ClearAll[sortfamily];
sortfamily[family_List, loops_List] := 
 Module[{}, (SortBy[#, Max@Exponent[#, loops] &] &)@family]