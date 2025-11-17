ClearAll[TogetherExpand, TogetherExpandDenominator]
TogetherExpand[expr_] := expr // Together // ExpandS
TogetherExpandDenominator[expr_] := expr // Together // ExpandS // ExpandDenominator