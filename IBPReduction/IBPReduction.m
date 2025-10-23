ClearAll[GatherGInFamily]
GatherGInFamily[Glist_List, family_List] := Module[{Glist2, Glist3},
  Glist2 = Join[Glist, G[#, "x"] & /@ (Range@Length@family)];
  Glist3 = Glist2 // GatherBy[#, #[[1]] &] & // SortBy[#, #[[1, 1]] &] &;
  DeleteCases[#, G[_, "x"]] & /@ Glist3
  ]

Clear[ApplyIBPRules]
ApplyIBPRules[expr_, {ibprules_Dispatch, ibpgAndMI_List}] := Module[{tp1},
  If[(tp1 = Complement[getS[expr, _G], ibpgAndMI]) =!= {}, Print["Unreduced target appear -> ", tp1]; Abort[]];
  expr /. ibprules
  ]

ClearAll[tosector, samesectorQ, subsectorQ, propNumG]
tosector[Gs_] := Gs /. G[a_, b_] :> G[a, Which[# > 1, 1, # < 0, 0, True, #] & /@ b]
samesectorQ[G1_, G2_] := Module[{tp1}, 
  tp1 = tosector /@ {G1, G2};
  tp1[[1]] === tp1[[2]]
  ]
subsectorQ[G1_, G2_] := Module[{s1, s2},
  If[Length @ G1[[2]] =!= Length @ G2[[2]], Return[False]];
  {s1, s2} = tosector /@ {G1, G2};
  AllTrue[s1[[2]] - s2[[2]], NonNegative] && s1[[1]] === s2[[1]]
  ]
propNumG[Gs_] := Select[Gs[[2]], # > 0 &] // Length
SetAttributes[propNumG, Listable]


ClearAll[IBPReduction]
IBPReduction::usage = "IBPReduction[Fslist_List, {family_List, problem_Integer}, loops_List, extmomsind_List, kinematics_List, {WorkPath_String, FamilyName_String}, opt : OptionsPattern[]].
Depending options: {FIREIBPReduction, TableS}.
WARN: Parallelization in MMA and in the external IBP program are independent. The total number of cores used equals their product.";
Options[IBPReduction] := CreateOptions[{"IBPReducer" -> "FIRE", "IBPReductionRange" -> All}, {FIREIBPReduction, TableS}];
IBPReduction[Fslist_List, family_List, loops_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := (
  Switch[OptionValue["IBPReducer"],
    "FIRE",
    IBPReduction[Fslist, family, loops, process["extmomsind"], process["kinematics"], {FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops]}, Evaluate@opt]
    ]
  )
IBPReduction[Fslist_List, family_List, loops_List, extmomsind_List, kinematics_List, {WorkPath_String, FamilyName_String}, opt : OptionsPattern[]] := Module[{i, rg, glistInfam, ibp1, ibprules, ibpgAndMI},
  rg = OptionValue["IBPReductionRange"];
  If[rg === All, rg = Range@Length@family];
  glistInfam = GatherGInFamily[Fslist, family];
  ibp1 = TableS[FIREIBPReduction[glistInfam[[i]], {family, i}, loops, extmomsind, kinematics, {WorkPath, FamilyName}, Evaluate@FilterOptions[{opt}, FIREIBPReduction]], {i, rg}, Evaluate@FilterOptions[{opt}, TableS]];
  {ibprules, ibpgAndMI} = {Dispatch@Flatten@ibp1, getS[ibp1, _G]};
  {ibprules, ibpgAndMI}
  ]


ClearAll[FamilyMerge];
FamilyMerge::usage = "FamilyMerge[Fslist0_List, loops_List, family_List, {ibprules_Dispatch, ibpgAndMI_List}, extmomsind_List, kinematics_List, opt : OptionsPattern[]].
Depending options: {FindRulesComplete, TableS}";
Options[FamilyMerge] := CreateOptions[{"PreferredMIs" -> {}, "FamilyMergeSimplify" :> SimplifyS}, {FindRulesComplete, TableS}];
FamilyMerge[Fslist_List, loops_List, family_List, {ibprules_Dispatch, ibpgAndMI_List}, process_Association : CurrentProcess, opt : OptionsPattern[]] := FamilyMerge[Fslist, loops, family, {ibprules, ibpgAndMI}, process["extmomsind"], process["kinematics"], Evaluate@opt]
FamilyMerge[Fslist0_List, loops_List, family_List, {ibprules_Dispatch, ibpgAndMI_List}, extmomsind_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, Fslist, Gs, GsRules, tp1, tp2, rules1, pref, prefRed, rules2, tpmi, tpeqs, tpmap},
  pref = OptionValue["PreferredMIs"];
  Fslist = Join[Fslist0, pref];
  (*find rules*)
  tp1 = Fslist // ApplyIBPRules[#, {ibprules, ibpgAndMI}]&;
  Gs = tp1 // getS[#, _G]&;
  GsRules = Monitor[FindRulesComplete[family, Gs, loops, {ibprules, ibpgAndMI}, kinematics, extmomsind, Evaluate@FilterOptions[{opt}, FindRulesComplete]], "FamilyMerge: FindRulesComplete..."];
  tp2 = tp1 /. Dispatch@GsRules;
  rules1 = Union@Join[Thread[Fslist -> tp2], GsRules];
  (*change MI basis*)
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
  (*return*)
  TableS[rules2[[i]] // Collect[#, _G, OptionValue["FamilyMergeSimplify"]] &, {i, Length @ rules2}, "FamilyMerge: Simplifying with option \"FamilyMergeSimplify\".", Method -> Automatic, Evaluate @ FilterOptions[{opt}, TableS]]
  ]