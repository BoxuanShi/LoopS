ClearAll[PolynomialCollect, PolynomialCollect0]
Options[PolynomialCollect] = {"PolynomialCollectOperation" -> Times};
PolynomialCollect[expr_, patt0_, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{vars, patt},
  patt = Alternatives @@ Flatten[{patt0}];
  vars = getS[{expr}, patt];
  PolynomialCollect0[expr, vars, opt]
  ]

Options[PolynomialCollect0] := CreateOptions[{}, {PolynomialCollect}];

PolynomialCollect0[expr_List, vars_List, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{tp1, tp2},
  If[vars === {}, Return[{}]];
  tp1 = Flatten@{expr};
  tp2 = (PolynomialCollect0[#, vars, opt] &) /@ tp1;
  Union @ Flatten[tp2, 1]
  ]

PolynomialCollect0[expr_, vars_List, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{sa, ar, ltop, tp1},
  If[expr === 0, Return[{}]];
  If[vars === {}, Return[{}]];
  sa = CoefficientArrays[expr, vars];
  ar = (ArrayRules /@ sa[[2 ;; -1]])[[All, 1 ;; -2]] // Flatten;
  ltop[list_] := OptionValue["PolynomialCollectOperation"] @@ (vars[[#]] & /@ list);
  tp1 = ar /. (x_ -> y_) :> ltop[x];
  Sort[tp1]
  ]