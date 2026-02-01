ClearAll[getImS, getReS]
getImS[expr_] := Module[{ii}, Coefficient[expr /. Complex[a_, b_] :> b*ii, ii]*I]
getReS[expr_] := expr /. Complex[a_, b_] :> a