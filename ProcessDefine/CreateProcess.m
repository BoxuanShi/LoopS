ClearAll[CreateProcess]
CreateProcess[expr__Association | expr__List | expr__Rule] := Module[{tp1, tp2, keys, purePV},
  (*pretransform*)
  tp1 = Association@@Union@Flatten@Normal[{expr}];
  keys = Keys[tp1];
  If[! SubsetQ[keys, {"ProcessName"}], Print["ProcessName is absent."];Abort[]];
  If[! SubsetQ[keys, {"loopmoms", "extmomsind"}], Print["loopmoms or extmomsind is absent."]; Abort[]];
  If[tp2 = (FactorTermsList[#][[2]] & /@ ((Plus @@ tp1["extmomsind"])^2 // Expand // ListS)) /. tp1["kinematics"]; !FreeQ[tp2, Alternatives@@extmomsind], Print[tp1["kinematics"],"kinematics is not sufficient for extmomsind."]; Abort[]];
  (*complete keys*)
  tp1 = If[FreeQ[Keys[tp1], "extmoms"], 
    Append[tp1, "extmoms" -> DeleteCases[Union@Flatten@{tp1["extmomsind"], tp1["extramoms"]}, _Missing]], 
    Append[tp1, "extmoms" -> Union@Flatten@{tp1["extmoms"], tp1["extmomsind"]}]];
  tp1 = Append[tp1, "extramoms" -> Complement[tp1["extmoms"], tp1["extmomsind"]]];
  tp1 = If[FreeQ[Keys[tp1], "indices"], Append[tp1, "indices" -> {}], tp1];
  tp1 = If[FreeQ[Keys[tp1], "moms"], Append[tp1, "moms" -> Join[tp1["loopmoms"], tp1["extmoms"]]], tp1];
  purePV = "purePV" <> tp1["ProcessName"];
  ToExpression[purePV, InputForm, Function[{x}, ClearAll[x], HoldAll]];
  Print[purePV, " is cleared, and is used to save PV Reduction."];
  Print["Set \"purePV\" -> symbol to custom the symbol used."];
  tp1 = If[FreeQ[Keys[tp1], "purePV"], Append[tp1, "purePV" -> purePV], tp1];
  ToExpression[purePV, InputForm, Function[{x}, x = <||>, HoldAll]];
  ToExpression[purePV, InputForm, Function[{x}, x[{}] = 1, HoldAll]];
  (* ToExpression[purePV, InputForm, Function[{x}, x[0] = 1, HoldAll]]; *)
  tp1 = If[FreeQ[Keys[tp1], "operatorRules"], Append[tp1, "operatorRules" -> {}], tp1];
  (*Sort*)
  tp1 = Normal[tp1] // SortBy[#, Position[Reverse@{"ProcessName", "loopmoms", "extmomsind", "kinematics", "extmoms", "moms", "extramoms", "indices", "purePV", "operatorRules"}, #[[1]]] &] &;
  (*Return*)
  Association@@Reverse@tp1
  ]