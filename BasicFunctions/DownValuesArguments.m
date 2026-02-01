ClearAll[DownValuesArguments]
DownValuesArguments[func_Symbol] := Module[{tp1, strcase},
  tp1 = DownValues[func][[All, 1]];
  tp1 = ToStringInput /@ tp1;
  strcase[str_String] := Module[{tps1},
    tps1 = StringCases[str, "[" ~~ __ ~~ "]", Overlaps -> True];
    tps1 = SortBy[tps1, StringLength][[1]];
    tps1 = StringDelete[tps1, "[" | "]"];
    StringJoin["{", tps1, "}"]
    ];
  tp1 = strcase /@ tp1;
  ToExpression /@ tp1
  ]