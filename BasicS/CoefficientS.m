ClearAll[CoefficientS, CoefficientCheckZero]
CoefficientS[expr : Except[_List], arg_] := Module[{tp1, tp2},
  tp1 = Coefficient[expr, arg];
  tp2 = expr - If[Head @ arg === List, tp1 . arg, tp1*arg];
  Flatten @ {tp1} ~ Join ~ {tp2}]

CoefficientCheckZero::nonzero = "CoefficientCheckZero: non-zero remainder.";
CoefficientCheckZero[expr : Except[_List], arg_] := Module[{tp1, tp2},
  tp1 = Coefficient[expr, arg];
  tp2 = expr /. Dispatch @ Thread[arg -> 0];
  If[tp2 =!= 0, Message[CoefficientCheckZero::nonzero]];
  tp1
  ]