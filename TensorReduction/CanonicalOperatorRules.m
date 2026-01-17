ClearAll[getdummyindices2]
(*only for PermutationRulesFromSets,CanonicalOperatorRules*)
getdummyindices2[expr_] := Module[{tp1, tp2},
  tp1 = getdummyindicesList[expr];
  tp2 = Intersection @@@ Subsets[tp1, {2}] // Union // DeleteCases[#, {}] &
]


ClearAll[CanonicalOperatorRules]
Options[CanonicalOperatorRules] := CreateOptions[{"Parallelization" -> False}, {NumeratorReduction, TableS}];
CanonicalOperatorRules[operatorRules_List, process_String : "CurrentProcess", opt : OptionsPattern[]] /; OptRestrict[opt] := CanonicalOperatorRules[operatorRules, ToExpression[process], opt]
CanonicalOperatorRules[operatorRules_List, process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := CanonicalOperatorRules[operatorRules, process["indices"], process["loopmoms"], process["moms"], process["extmomsind"], process["purePV"], opt]
CanonicalOperatorRules[operatorRules_List, indices_List, loopmoms_List, moms_List, extmomsind_, purePV_String, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{operatorRules0, operatorRules2, OPERAT, opelist, opttable, optnum, tp0, tp1, tp1x, tp2, tp3, i, j, res},
  Block[{Monitor = (#&)},
    (*preprocessing*)
    operatorRules0 = Union @ Normal @ operatorRules /. Pattern -> (# &) ;
    (*options*)
    opttable = FilterOptions[{opt}, TableS];
    optnum = FilterOptions[{opt}, NumeratorReduction];
    (*reduce input operators to canonical operators with head OPERAT*)
    tp1x = TableS[NumeratorReduction[operatorRules0[[i, 1]], indices, {}, loopmoms, moms, extmomsind, purePV, "OperatorReplace" -> False, "OperatorHead" -> OPERAT, optnum], {i, Length@operatorRules0}, Evaluate@opttable];
    (*get all _OPERAT and check completeness*)
    opelist = getS[tp1x, _OPERAT];
    If[Length@opelist > Length@operatorRules0, 
    Print["operatorRules is not complete.", opelist /. OPERAT -> (# &)]; 
    Abort[]
    ];
    (*find neat rules: operatorRules2*)
    operatorRules2 = Solve[tp1x == operatorRules0[[All, 2]], opelist];
    If[operatorRules2 === {}, Print["operatorRules is not consistant."]; Abort[]];
    operatorRules2 = operatorRules2[[1]] /. OPERAT -> (# &);
    (*generate all permutations*)
    tp0 = getdummyindices2 /@ operatorRules2[[All, 1]];
    tp1 = PermutationRulesFromSets @@@ tp0;
    tp2 = Flatten@TableS[
      operatorRules2[[i, 1]] /. Dispatch[tp1[[i]]] /. 
        Dot[a___, x__, b___] /; (And @@ Table[! FreeQ[{x}[[j]], Alternatives @@ Flatten@tp0[[i]]], {j, Length@{x}}]) && FreeQ[{a, b}, Alternatives @@ Flatten@tp0[[i]]] :> Dot[a, Sequence @@ Sort[{x}], b]
      , {i, Length@tp1}] // RenameDummyInd;
    (*reduce generated redundant operators*)
    tp3 = TableS[NumeratorReduction[tp2[[i]], indices, Dispatch@operatorRules2, loopmoms, moms, extmomsind, purePV, optnum], {i, Length@tp2}, Evaluate@opttable];
    (*return*)
    res = Union@Thread[tp2 -> tp3];
    res = Reverse@SortBy[res, LeafCount@First@# &];
    res
  ]
]