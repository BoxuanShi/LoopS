ClearAll[OperatorCollect, RefineSpinor];
Options[OperatorCollect] := CreateOptions[{}, {PolynomialCollect}]
OperatorCollect[expr_, opt : OptionsPattern[]] := 
 PolynomialCollect[expr, OperatorPattern, Evaluate@opt]

RefineSpinor[expr_] := getDo[expr, _Spinor, RefineSpinor]
RefineSpinor[expr_Spinor] := Module[{tp1},
  tp1 = getS[expr, _Momentum];
  If[Length@tp1 > 1, Print["More than one Momentum in the ", expr]; Abort[]];
  expr /. 
   Spinor[a_, b__] /; (Pair[tp1[[1]], tp1[[1]]] === 0) :> Spinor[tp1[[1]], b]
  ]