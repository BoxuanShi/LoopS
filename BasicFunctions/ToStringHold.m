ClearAll[ToStringHold]
ToStringHold[expr_] := StringTake[ToString[Hold[expr]], {6, -2}]
Attributes[ToStringHold] = {HoldAll};


ClearAll[ToStringInput]
ToStringInput[expr_] := ToString[expr, InputForm]