ClearAll[TableFormS]
TableFormS[expr_List] := 
 Module[{i}, Do[Print[ToString[i] <> ": ", expr[[i]]], {i, Length@expr}]]