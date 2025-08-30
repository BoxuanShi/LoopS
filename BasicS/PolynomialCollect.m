PolynomialCollect;

ClearAll[PolynomialCollect, PolynomialCollect0]
PolynomialCollect[expr_, patt0_] := Module[{vars, patt},
  patt = Alternatives @@ Flatten[{patt0}];
  vars = getS[{expr}, patt];
  PolynomialCollect0[expr, vars]
  ]

PolynomialCollect0[expr_List, vars_List] := Module[{tp1, tp2},
  If[vars === {}, Return[{}]];
  tp1 = Flatten@{expr};
  tp2 = (PolynomialCollect0[#, vars] &) /@ tp1;
  Union@Flatten@tp2
  ]

PolynomialCollect0[expr_, vars_List] := Module[{sa, ar, ltop, tp1},
  If[expr === 0, Return[{}]];
  If[vars === {}, Return[{}]];
  sa = CoefficientArrays[expr, vars];
  ar = (ArrayRules /@ sa[[2 ;; -1]])[[All, 1 ;; -2]] // Flatten;
  ltop[list_] := Times @@ (vars[[#]] & /@ list);
  tp1 = ar /. (x_ -> y_) :> ltop[x];
  Sort[tp1]
  ]