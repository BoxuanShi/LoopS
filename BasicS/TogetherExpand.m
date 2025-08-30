TogetherExpand;

ClearAll[TogetherExpand]
TogetherExpand[expr_] := expr // Together // Expand