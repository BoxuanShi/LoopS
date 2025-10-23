ClearAll[sameSetQ]
sameSetQ[a_, b_, testfunc_ : (#1 === #2 &)] := SubsetQ[a, b, SameTest -> testfunc] && SubsetQ[b, a, SameTest -> testfunc]