ClearAll[ExpandS];
ExpandS[expr_Plus, patt_:_] := Expand[#, patt]& /@ expr;
ExpandS[expr_, patt_:_] := Expand[expr, patt];