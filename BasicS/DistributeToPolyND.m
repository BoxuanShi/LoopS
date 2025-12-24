ClearAll[DistributeToPolyND, DistributeToPolyND0];
DistributeToPolyND::unkstruc = "DistributeToPolyND0: Encountered unknow structures. Use Together or Factor Firstly. Together is used instead.";
SetAttributes[DistributeToPolyND, Listable];
DistributeToPolyND[expr_] := Total@Flatten@DistributeToPolyND0[{expr}]
DistributeToPolyND0[expr_] := DistributeToPolyND0[expr, Variables[expr]];
DistributeToPolyND0[expr_Plus, vars_List] := DistributeToPolyND0[List @@ expr, vars]; 
DistributeToPolyND0[expr_List, vars_List] := Flatten[(DistributeToPolyND0[#1, vars] &) /@ expr]; 
DistributeToPolyND0[expr_, vars_List] := Module[{ND, tp1},
  ND = {Numerator[expr], Denominator[expr]};
  If[! AllTrue[ND, PolynomialQ],
    If[
    (tp1 = Distribute[expr, Plus, Times]) =!= expr,
    Return[DistributeToPolyND0[tp1, vars]],
    (* Message[DistributeToPolyND::unkstruc];  *)
    Return[Together[expr]];
    ],
    expr
  ]
]