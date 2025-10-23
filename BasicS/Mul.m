ClearAll[Mul];
Protect[Mulq];
Options[Mul] := CreateOptions[{}, {MultivariateAbbreviatedApart}];
Mul[expr_List, func : Except[_Rule|_RuleDelayed, _Function|_Symbol] : (# &), opt : OptionsPattern[]] := Mul[#, func, opt] & /@ expr;
Mul[expr_, func : Except[_Rule|_RuleDelayed, _Function|_Symbol] : (# &), opt : OptionsPattern[]] := Module[{tp1, optM},
  optM = FilterOptions[{opt}, MultivariateAbbreviatedApart];
  tp1 = expr // MultivariateAbbreviatedApart[#, InverseSymbol -> Mulq, optM] &;
  tp1[[1]] = func[tp1[[1]]];
  tp1[[1]] /. Dispatch[tp1[[2]]]
]

ClearAll[$ApartTemporaryDirectory];
$ApartTemporaryDirectory := "tempmul/" <> "mul" <> ToString[$KernelID]
