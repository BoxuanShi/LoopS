Separate;

ClearAll[Separate, SeparatePoly];
Separate[expr_, patt_] := Module[{x, vars},
  vars = getS[{expr}, patt];
  SeparatePoly[expr, vars]
  ]

Separate[expr_, patt0_List] := Module[{i, coe, patt, tp1, tp2, dvQ, matchQ},
  {coe, patt} = Separate[expr, Alternatives @@ patt0];
  patt = (ListS[#, {}, Times] &) /@ patt;
  patt = (Table[
       Select[#, MatchQ[# /. a_^b_ :> a, patt0[[i]]] &], {i, 
        Length@patt0}] &) /@ patt;
  patt = (Times @@@ # &) /@ patt;
  patt = Transpose@patt;
  {coe, Sequence @@ patt}
  ]

SeparatePoly[expr_, vars_List] := Module[{sa, ar, ltop, tp1},
  If[expr === 0, Return[{{}, {}}]];
  If[vars === {}, Return[{{expr}, {1}}]];
  sa = CoefficientArrays[expr, vars];
  ar = (ArrayRules /@ sa[[2 ;; -1]])[[All, 1 ;; -2]] // Flatten;
  ltop[list_] := Times @@ (vars[[#]] & /@ list);
  tp1 = ar /. (x_ -> y_) :> {y, ltop[x]};
  tp1 = SortBy[tp1, Last];
  If[sa[[1]] === 0, Nothing, PrependTo[tp1, {sa[[1]], 1}]];
  Transpose[tp1]
  ]