CoefficientS;

ClearAll[CoefficientS]
CoefficientS[expr_, arg_, simplify_ : (# &)] /; Head@expr =!= List := 
 Module[{tp1, tp2},
  tp1 = Coefficient[expr, arg];
  tp2 = expr - If[Head@arg === List, tp1 . arg, tp1*arg] // Simplify;
  Flatten@{tp1}~Join~{tp2}
  ]