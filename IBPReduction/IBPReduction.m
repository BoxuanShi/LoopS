ClearAll[GatherGInFamily]
GatherGInFamily[Glist_List, family_List] := Module[{Glist2, Glist3},
  Glist2 = Join[Glist, G[#, "x"] & /@ (Range@Length@family)];
  Glist3 = Glist2 // GatherBy[#, #[[1]] &] & // SortBy[#, #[[1, 1]] &] &;
  DeleteCases[#, G[_, "x"]] & /@ Glist3
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


ClearAll[ApplyIBPRules]
ApplyIBPRules::usage="ApplyIBPRules[expr_, ibpsystem : {_Dispatch, {_List, _List}}]: check whether all targets can be reduced and apply ibp rules from ibprules.";
ApplyIBPRules[expr_, ibpsystem : {_Dispatch, {_List, _List}}] := Module[{tp1},
  If[(tp1 = Complement[getS[expr, _G], Flatten@ibpsystem[[2]]]) =!= {}, Print["Unreduced target appear -> ", tp1]; Abort[]];
  expr /. ibpsystem[[1]]
  ]
ApplyIBPRules[expr_, rawrules_List] := ApplyIBPRules[expr, ToIBPSystem[rawrules]]


ClearAll[ToIBPSystem];
ToIBPSystem::usage="IBPSystem[rawrules_List] generate ibp system from a list of ibp reduction rules.";
ToIBPSystem[ibpsystem : {_Dispatch, {_List, _List}}] := ibpsystem
ToIBPSystem[rawrules_List] := {Dispatch@#, {getS[#[[All,1]], _G], getS[#[[All,2]], _G]}}& @Flatten@rawrules


ClearAll[FamilyMerge];
FamilyMerge::usage = "FamilyMerge find rules between sectors and families.
FamilyMerge[Fslist0_List, family_List, rawibprules_List, loops_List, extmomsind_List, kinematics_List, opt : OptionsPattern[]].
Depending options: {FindRulesComplete, TableS}";
Options[FamilyMerge] := CreateOptions[{"PreferredMIs" -> {}, "FamilyMergeSimplify" :> SimplifyS}, {FindRulesComplete, TableS}];
FamilyMerge[Fslist_List, family_List, rawibprules_List, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, FamilyMerge[Fslist, family, rawibprules, loops, p["extmomsind"], p["kinematics"], Evaluate@opt]]
FamilyMerge[Fslist0_List, family_List, rawibprules_List, loops_List, extmomsind_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, Fslist, Gs, GsRules, tp1, tp2, rules1, pref, prefRed, rules2, tpmi, tpeqs, tpmap, ibpsystem},
  ibpsystem = ToIBPSystem[rawibprules];
  pref = OptionValue["PreferredMIs"];
  Fslist = Join[Fslist0, pref];
  (*find rules*)
  tp1 = Fslist // ApplyIBPRules[#, ibpsystem]&;
  Gs = tp1 // getS[#, _G]&;
  GsRules = Monitor[FindRulesComplete[Gs, family, ibpsystem, loops, kinematics, extmomsind, Evaluate@FilterOptions[{opt}, FindRulesComplete]], "FamilyMerge: FindRulesComplete..."];
  tp2 = tp1 /. Dispatch@GsRules;
  rules1 = Union@Join[Thread[Fslist -> tp2], GsRules];
  (*change MI basis*)
  rules2 = If[pref === {},
    rules1,
    Monitor[
    prefRed = (ApplyIBPRules[pref, ibpsystem] /. Dispatch@rules1);
    tpmi = prefRed // getS[#, _G]&;
    tpeqs = Thread[pref == prefRed];
    tpmap = Solve[tpeqs, tpmi][[1]];
    Thread[rules1[[All,1]] -> (rules1[[All,2]] /. Dispatch @ tpmap)]
    ];
    , "Transforming to the PreferredMIs..."];
  (*return*)
  TableS[rules2[[i]] // Collect[#, _G, OptionValue["FamilyMergeSimplify"]] &, {i, Length @ rules2}, "FamilyMerge: Simplifying with option \"FamilyMergeSimplify\".", Method -> Automatic, Evaluate@FilterOptions[{opt}, TableS]]
]


(* ClearAll[FindSectorCorrelations]
FindSectorCorrelations::usage = "FindSectorCorrelations[MI_G,MIList_List,symsectors_List,MergeRules:_List|_Dispatch]";
FindSectorCorrelations[MIList_List, symsectors_List, MergeRules : _List | _Dispatch, opt : OptionsPattern[]] := FindSectorCorrelations[#, MIList, symsectors, MergeRules, opt] & /@ MIList
FindSectorCorrelations[MI_G, MIList_List, symsectors_List, MergeRules : _List | _Dispatch] := Module[{tp1, tp2, tp3},
  tp1 = Select[tosector@symsectors, subsectorQ[MI, #] &];
  tp2 = tp1 /. Dispatch@MergeRules // DeleteCases[#, Except[_G], {1}] &;
  tp3 = Position[MIList, #, {1}][[1]] & /@ Intersection[tp2, MIList] // Sort;
  ReplacePart[ConstantArray[0, Length@MIList], tp3 -> 1]
] *)


ClearAll[FindSectorCorrelations]
FindSectorCorrelations[MIList_List, symsectors_List, MergeRules : _List | _Dispatch, opt : OptionsPattern[]] := FindSectorCorrelations[#, MIList, symsectors, MergeRules, opt] & /@ MIList
FindSectorCorrelations[MI_G, MIList_List, symsectors_List, MergeRules : _List | _Dispatch] := Module[{tp1, tp2, tp3},
  tp1 = Select[tosector@symsectors, subsectorQ[MI, #] &];
  tp2 = tp1 /. MergeRules // DeleteCases[#, Except[_G], {1}] &;
  tp3 = Position[MIList, #, {1}][[1]] & /@ Intersection[tp2, MIList] // Sort;
  ReplacePart[ConstantArray[0, Length@MIList], tp3 -> 1]
]


ClearAll[FindSymmetriedSectors]
Options[FindSymmetriedSectors] = {"Parallelization"->False};
FindSymmetriedSectors[MIsNoMerge_?VectorQ, family_List, loops_List, process_Association : Hold@CurrentProcess, opt:OptionsPattern[]] := Module[{p=ReleaseHold@process}, FindSymmetriedSectors[MIsNoMerge, family, loops, p["kinematics"], p["extmomsind"], opt]]
FindSymmetriedSectors[MIsNoMerge_?VectorQ, {familyi_?VectorQ, problem_Integer}, loops_List, kinematics_List, extmomsind_List, opt:OptionsPattern[]] := FindSymmetriedSectors[Cases[MIsNoMerge, G[problem, __]] /. G[problem, x__] :> G[1, x], {familyi}, loops, kinematics, extmomsind, opt] /. G[1, x__] :> G[problem, x]
FindSymmetriedSectors[MIsNoMerge_?VectorQ, family_?MatrixQ, loops_List, kinematics_List, extmomsind_List, OptionsPattern[]] := Module[{i, res},
  $FindSymmetriedSectorsMIsNoMerge2 = GroupBy[tosector@MIsNoMerge,#[[1]]&]/@(Range@Length@family)/._Missing:>{};
  $FindSymmetriedSectorstpfun1[expr_] := Module[{i2,tpf1,tpf2,tpf3,tpf4},
    tpf1=expr//DeleteDuplicates[#,(#1[[1]]===#2[[1]])&&(Total[#1[[2]]]===Total[#2[[2]]])&]&;
    tpf2=Table[G[tpf1[[i2,1]], #]& /@ Permutations[tpf1[[i2,2]]]//DropZeroSector[#, family, loops, kinematics]& //DeleteCases[#,0]&, {i2, Length@tpf1}] // Flatten;
    tpf3=tpf2//findrules[family,#,loops,kinematics,extmomsind]&;
    tpf4=Select[tpf3, !FreeQ[#, Alternatives@@(expr/.Dispatch@tpf3)]&];
    {expr,tpf4} // getS[#, _G]&
  ];
  If[OptionValue["Parallelization"],DumpDistribute[$FindSymmetriedSectorsMIsNoMerge2,$FindSymmetriedSectorstpfun1]];
  res=TableS[$FindSymmetriedSectorstpfun1[$FindSymmetriedSectorsMIsNoMerge2[[i]]],{i,Length@family},"Parallelization"->OptionValue["Parallelization"],DistributedContexts->None];
  Flatten[res]
]