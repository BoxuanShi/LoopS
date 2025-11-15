ClearAll[ExpandS];
ExpandS[expr_Plus] := Expand /@ expr;
ExpandS[expr_] := Expand[expr];