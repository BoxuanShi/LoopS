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
FamilyMerge[Fslist_List, family_List, rawibprules_List, loops_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := FamilyMerge[Fslist, family, rawibprules, loops, process["extmomsind"], process["kinematics"], Evaluate@opt]
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