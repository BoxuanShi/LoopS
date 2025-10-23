ClearAll[TogetherExpand, TogetherExpandDenominator]
TogetherExpand[expr_] := expr // Together // Expand
TogetherExpandDenominator[expr_] := expr // Together // Expand // ExpandDenominator