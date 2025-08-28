FamilyClassify;

ClearAll[FamilyClassify];
(*the option "SortRules" is to prevent inconsistencies in the family \
classification caused by version updates.*)
Options[FamilyClassify] := 
  CreateOptions[{"SortRules" -> {-Length[#] &, #[[All, 
        1 ;; 3]] &}}, {FindfamilyG, LSsubsets, GetFeynInt, CompleteProps, 
    TableS, CanonicalLoops}];
FamilyClassify[propslistlist_, loops_, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FamilyClassify[propslistlist, loops, ToExpression[process], opt]
FamilyClassify[propslistlist_, loops_, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FamilyClassify[propslistlist, loops, process["kinematics"], 
  process["extmomsind"], process["moms"], opt]
FamilyClassify[propslistlist_, loops_, kinematics_, extmomsind_, moms_, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, fadQ, tp0, tp1, tp2, tp3, tp4, tp5, tp6, tp7, optget, optFG, 
   opttable, optc, num, NofL, familyLS, optLS, optLSsub},
  optc = FilterOptions[{opt}, CompleteProps];
  Print["CompleteBasis is: ", CompleteProps[{}, loops, optc]];
  
  fadQ = ! FreeQ[propslistlist, FAD | SFAD | FeynAmpDenominator];
  
  opttable = FilterOptions[{opt}, TableS];
  
  tp1 = If[fadQ,
    optget = FilterOptions[{opt}, GetFeynInt];
    tp0 = GetFeynInt[{propslistlist}, loops, moms, kinematics, optget];
    TableS[
     propsToLS[FADToProps[tp0[[i]], List], loops, kinematics], {i, 
      Length@tp0}, Evaluate@opttable]
    ,
    propsToLS /@ propslistlist
    ];
  
  optLS = FilterOptions[{opt}, CanonicalLoops];
  tp2 = TableS[
    CanonicalLoops[tp1[[i]], loops, moms, kinematics, Evaluate@optLS][[
     1]], {i, Length@tp1}, Evaluate@opttable];
  tp3 = tp2 // UnionS[#, #1[[All, 1 ;; 3]] === #2[[All, 1 ;; 3]] &] & // 
    SortBy[#, OptionValue["SortRules"]] &;
  
  tp4 = LSToprops[#, kinematics] & /@ tp3;
  
  optFG = FilterOptions[{opt}, FindfamilyG];
  optLSsub = FilterOptions[{opt}, LSsubsets];
  
  Block[{Print = # &},
   Monitor[
    For[num = 1; familyLS = {{}, {}}, num <= Length@tp4, num++,
     If[FindfamilyG[tp4[[num]], familyLS, loops, moms, kinematics, 
        "FindfamilyGDefault" -> Return[False], "FGMode" -> "familySearch", 
        optFG] === False,
      AppendTo[familyLS[[1]],(*(sortfamily[#,loops]&)@*)
       CompleteProps[(sortfamily[#, loops] &)@
         tp4[[num]](*move sortfamily here*), loops, extmomsind, optc]];
      AppendTo[familyLS[[2]], 
       LSsubsets[(*familyLS[[1,-1]]*)tp4[[num]], loops, moms, kinematics, 
        optLSsub]];
      ]
     ], {num, Length@tp4}]
   ];
  
  {familyLS, familyLS[[1]]}
  ]


ClearAll[sortfamily];
sortfamily[family_List, loops_List] := Module[{symQ, i, tpf, tp1, tpR},
  (SortBy[#, Max@Exponent[#, loops] &] &)@family
  ]