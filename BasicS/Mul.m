Mul;

ClearAll[Mul, Mul0];
Protect[Mulq];
Options[Mul] := CreateOptions[{}, {Mul0}];
Mul[expr_, func_Symbol : (# &), opt : OptionsPattern[]] := 
 Mul0[expr, "func" -> func, opt]
Mul[expr_, func_Function : (# &), opt : OptionsPattern[]] := 
 Mul0[expr, "func" -> func, opt]
Options[Mul0] := 
  CreateOptions[{"func" -> (# &)}, {MultivariateAbbreviatedApart}];
Mul0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, optM},
  optM = FilterOptions[{opt}, MultivariateAbbreviatedApart];
  tp1 = expr // MultivariateAbbreviatedApart[#, InverseSymbol -> Mulq, optM] &;
  tp1[[1]] = OptionValue["func"][tp1[[1]]];
  tp1[[1]] /. Dispatch[tp1[[2]]]
  ]
SetAttributes[Mul0, Listable]


ParallelLoad["$ApartTemporaryDirectory"] := Module[{},
  ClearAll[$ApartTemporaryDirectory];
  $ApartTemporaryDirectory := "tempmul/" <> "mul" <> ToString[$KernelID]
  ]
ParallelLoad["$ApartTemporaryDirectory"]
